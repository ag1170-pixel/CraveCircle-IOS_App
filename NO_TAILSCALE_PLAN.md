# CraveCircle — "No Tailscale, any iPhone" plan

Goal: hand someone an install, they open it, it works — **no Tailscale, no per-user server setup,
no Xcode**. This is a plan, not yet built. See also `PRIORITIZED_TASKS.md` P3.1.

## What actually ties us to Tailscale today
**Only one thing:** the **link/URL reel-import** backend (yt-dlp + Whisper) at the homelab IP
(`AppConfig.defaultHost` = `100.70.151.71:8009` / the Mac relay). Everything else is already free of it:

| Capability | Needs Tailscale? |
|---|---|
| Sign-in, database, community, shares, recs | ❌ Public **cloud Supabase** (done) |
| **On-device import** (share/pick a video) | ❌ Runs 100% on the phone |
| Browse, save, cook, grocery, deep links | ❌ Local / cloud |
| **Paste-a-link import** | ✅ Homelab (the only dependency) |

So a fresh install **already works** for everything except pasting a reel link. Fixing that one path
removes Tailscale entirely.

## The plan (3 steps)

### 1. Deploy the import backend to a public host
The FastAPI container (`whisper-transcriber/`) is already built — it just lives on the homelab. Move it:
- **Host:** Fly.io / Railway / Render / a small VPS (Hetzner/DO). A public **HTTPS** URL — it's an API
  endpoint, not a website, so this doesn't conflict with "app-only, no website."
- **Transcription:** keep faster-whisper, **or** swap to a managed **Groq Whisper API** (~pennies per
  reel) so there's no model to run — then the box is just a thin yt-dlp downloader + an API call.
- **Cookies:** store `cookies.txt` (IG/TikTok auth) as a host secret; refresh periodically (ops task).
- **Cost:** low import volume → a **$5/mo VPS** or a **scale-to-zero** container. Bounded.

> The one irreducible piece: yt-dlp must run in a container somewhere (can't be a pure serverless API
> — no Python binary, short timeouts). That's a $5 box, not a laptop.

### 2. Point the app at the public URL
- Set `AppConfig.defaultHost` → `https://<public-api-host>` (remove the Tailscale/relay IP).
- Demote the Profile **"Kitchen Server"** custom-URL row to an **advanced/dev override** — normal users
  never touch it; it defaults to the public host.
- ATS: HTTPS needs no `NSAllowsArbitraryLoads` (can tighten the current local-HTTP exception).

### 3. Distribute without Xcode
- Ship via **TestFlight** (then App Store). "I'll install it on their iPhone" = send a TestFlight link
  — no Tailscale, no cable, no signing per device.
- Needs: an Apple Developer account, app icons/metadata (have), and the two manual bits already open
  (email-confirm off, remove DEBUG dev-bypass).

## End state
A person taps a TestFlight link → installs → signs in (cloud Supabase) → imports by **sharing/picking a
video** (on-device, instant) **or pasting a link** (public API). Nothing about Tailscale, the homelab,
or a dev Mac is involved.

## Migration checklist
- [ ] Deploy `whisper-transcriber/` to a public host (Fly.io/VPS) with HTTPS
- [ ] (Optional) swap faster-whisper → Groq Whisper API
- [ ] Move `cookies.txt` to a host secret + set a refresh reminder
- [ ] `AppConfig.defaultHost` → public URL; Kitchen Server = advanced override
- [ ] Tighten ATS to HTTPS-only
- [ ] TestFlight build; remove DEBUG dev-bypass; email-confirm off
- [ ] Keep the homelab as a **dev** backend only

**Interim (today):** for a friend without Tailscale right now, on-device import already works — tell them
to **share the reel to CraveCircle** (or pick the video) rather than pasting a link, until step 1 ships.
