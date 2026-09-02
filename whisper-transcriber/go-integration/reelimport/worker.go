// Worker loop for the reel-import pipeline.
//
// Postgres-backed job queue — no Redis. Multiple workers claim queued jobs with
// `SELECT … FOR UPDATE SKIP LOCKED`, so each job runs exactly once even across
// several go-api replicas. Long transcription runs OUTSIDE the row lock (the claim
// tx is short); a stale-job reclaimer re-queues anything a crashed worker abandoned.
//
// Expected `import_jobs` columns (adjust names to your schema):
//   id             uuid  pk
//   owner_id       uuid
//   source_url     text
//   target_language text            -- user's preferred recipe language at import time ("" = none)
//   status         text            -- queued|downloading|transcribing|extracting|done|error
//   recipe_id      uuid  null
//   error_message  text  null
//   created_at     timestamptz
//   updated_at     timestamptz
//
// Recommended index:  CREATE INDEX ON import_jobs (status, created_at);

package reelimport

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"sync"
	"time"
)

type Worker struct {
	DB       *sql.DB
	Pipeline *Pipeline

	Concurrency  int           // parallel workers (default 2)
	PollInterval time.Duration // idle poll gap (default 2s)
	StaleAfter   time.Duration // re-queue jobs stuck in a processing state (default 10m)
}

// Start blocks until ctx is cancelled, then drains in-flight jobs and returns.
func (w *Worker) Start(ctx context.Context) {
	if w.Concurrency <= 0 {
		w.Concurrency = 2
	}
	if w.PollInterval <= 0 {
		w.PollInterval = 2 * time.Second
	}
	if w.StaleAfter <= 0 {
		w.StaleAfter = 10 * time.Minute
	}

	var wg sync.WaitGroup
	for i := 0; i < w.Concurrency; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			w.loop(ctx, id)
		}(i)
	}

	// Housekeeping: periodically re-queue jobs abandoned by crashed workers.
	wg.Add(1)
	go func() {
		defer wg.Done()
		t := time.NewTicker(w.StaleAfter / 2)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				if n, err := w.reclaimStale(ctx); err != nil {
					log.Printf("reelimport: reclaim stale failed: %v", err)
				} else if n > 0 {
					log.Printf("reelimport: re-queued %d stale job(s)", n)
				}
			}
		}
	}()

	wg.Wait()
}

func (w *Worker) loop(ctx context.Context, workerID int) {
	for {
		if ctx.Err() != nil {
			return
		}

		job, ok, err := w.claimNext(ctx)
		if err != nil {
			log.Printf("reelimport[%d]: claim error: %v", workerID, err)
			if !sleep(ctx, w.PollInterval) {
				return
			}
			continue
		}
		if !ok {
			if !sleep(ctx, w.PollInterval) { // nothing queued — back off
				return
			}
			continue
		}

		// Process outside any DB lock. pipeline.Run updates status + Complete/Fail itself.
		// Detach from ctx cancellation slightly so an in-flight job finishes on shutdown,
		// but still cap it so a hung download can't block drain forever.
		runCtx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
		id, perr := w.Pipeline.Run(runCtx, job)
		cancel()
		if perr != nil {
			log.Printf("reelimport[%d]: job %s failed: %v", workerID, job.ID, perr)
		} else {
			log.Printf("reelimport[%d]: job %s -> recipe %s", workerID, job.ID, id)
		}
	}
}

// claimNext atomically grabs one queued job and marks it downloading, so no other
// worker (or replica) can take it. The SELECT … FOR UPDATE SKIP LOCKED is the whole trick.
func (w *Worker) claimNext(ctx context.Context) (Job, bool, error) {
	tx, err := w.DB.BeginTx(ctx, nil)
	if err != nil {
		return Job{}, false, err
	}
	defer func() { _ = tx.Rollback() }() // no-op after a successful Commit

	var job Job
	err = tx.QueryRowContext(ctx, `
		SELECT id, owner_id, source_url, COALESCE(target_language, '')
		FROM import_jobs
		WHERE status = 'queued'
		ORDER BY created_at
		FOR UPDATE SKIP LOCKED
		LIMIT 1
	`).Scan(&job.ID, &job.OwnerID, &job.URL, &job.TargetLanguage)
	if errors.Is(err, sql.ErrNoRows) {
		return Job{}, false, nil
	}
	if err != nil {
		return Job{}, false, err
	}

	if _, err = tx.ExecContext(ctx,
		`UPDATE import_jobs SET status = 'downloading', updated_at = now() WHERE id = $1`,
		job.ID,
	); err != nil {
		return Job{}, false, err
	}

	if err = tx.Commit(); err != nil {
		return Job{}, false, err
	}
	return job, true, nil
}

// reclaimStale re-queues jobs stuck in a processing state past StaleAfter (crashed worker).
func (w *Worker) reclaimStale(ctx context.Context) (int64, error) {
	res, err := w.DB.ExecContext(ctx, `
		UPDATE import_jobs
		SET status = 'queued', updated_at = now()
		WHERE status IN ('downloading', 'transcribing', 'extracting')
		  AND updated_at < now() - $1::interval
	`, w.StaleAfter.String())
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// sleep returns false if ctx was cancelled during the wait.
func sleep(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}
