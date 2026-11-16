import asyncio
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

_database_dir = tempfile.TemporaryDirectory()
os.environ["DB_PATH"] = os.path.join(_database_dir.name, "test.sqlite3")
os.environ.pop("COOKIES_BROWSER", None)
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import main


class YtDlpTimeoutTests(unittest.TestCase):
    def test_download_subprocess_has_a_hard_timeout(self):
        with patch.object(main, "COOKIES_FILE", ""), patch.object(
            main.subprocess, "run", return_value=main.subprocess.CompletedProcess([], 0, "{}", "")
        ) as run:
            main._run_ytdlp(["--dump-json"], "https://example.com/video")
        self.assertEqual(run.call_args.kwargs["timeout"], main.YTDLP_TIMEOUT_S)

    def test_timeout_becomes_a_retryable_import_error(self):
        timed_out = main.subprocess.TimeoutExpired(["yt-dlp"], main.YTDLP_TIMEOUT_S)
        with patch.object(main, "COOKIES_FILE", ""), patch.object(
            main.subprocess, "run", side_effect=timed_out
        ):
            with self.assertRaisesRegex(RuntimeError, "download timed out"):
                main._run_ytdlp(["--dump-json"], "https://example.com/video")


class PersistentImportTests(unittest.TestCase):
    def setUp(self):
        with main._db_transaction() as conn:
            conn.execute("DELETE FROM imported_recipes")
            conn.execute("DELETE FROM import_jobs")
        main.RECIPES.clear()

    def test_queued_job_survives_and_is_marked_failed_after_restart(self):
        job = {
            "id": "job-restart-test", "status": "queued", "url": "https://example.com/reel",
            "target_language": "en", "user_id": None, "recipe_id": None,
            "error_message": None,
        }
        main._create_import_job(job)
        main._restore_import_state()
        restored = main._get_import_job(job["id"])
        self.assertEqual(restored["status"], "error")
        self.assertIn("backend restart", restored["error_message"])

    def test_completed_recipe_and_job_are_durable_together(self):
        job = {
            "id": "job-complete-test", "status": "queued", "url": "https://example.com/reel",
            "target_language": "en", "user_id": None, "recipe_id": None,
            "error_message": None,
        }
        recipe = {"id": "recipe-durable-test", "title": "Test", "ingredients": []}
        main._create_import_job(job)
        main._complete_import_job(job["id"], recipe)
        main.RECIPES.clear()
        main._restore_import_state()
        self.assertEqual(main._get_import_job(job["id"])["status"], "done")
        self.assertEqual(main.RECIPES[recipe["id"]]["title"], "Test")

    def test_import_result_is_private_and_removed_after_delivery(self):
        job = {
            "id": "job-private-test", "status": "queued", "url": "https://example.com/reel",
            "target_language": "en", "user_id": None, "recipe_id": None,
            "error_message": None,
        }
        recipe = {"id": "recipe-private-test", "title": "Private", "ingredients": []}
        main._create_import_job(job)
        main._complete_import_job(job["id"], recipe)
        self.assertTrue(main.RECIPES[recipe["id"]]["private_import"])
        listed = asyncio.run(main.list_recipes())
        self.assertNotIn(recipe["id"], {item["id"] for item in listed})
        delivered = asyncio.run(main.get_recipe(recipe["id"]))
        self.assertEqual(delivered["title"], "Private")
        self.assertNotIn(recipe["id"], main.RECIPES)
        self.assertIsNone(main._get_import_job(job["id"]))


class NutritionVolumeTests(unittest.TestCase):
    def test_common_ingredient_cups_use_distinct_masses(self):
        self.assertAlmostEqual(main._parse_grams("1 cup all-purpose flour"), 120)
        self.assertAlmostEqual(main._parse_grams("1 cup sugar"), 200)
        self.assertAlmostEqual(main._parse_grams("1 cup milk"), 240)

    def test_volume_units_use_density_and_unknown_food_is_not_guessed(self):
        self.assertAlmostEqual(main._parse_grams("250 ml water"), 250, places=1)
        self.assertAlmostEqual(main._parse_grams("1 tbsp oil"), 13.625, places=1)
        self.assertIsNone(main._parse_grams("1 cup mystery ingredient"))
        self.assertIsNone(main._parse_grams("30 ml mystery ingredient"))

    def test_unmeasurable_volume_is_omitted_from_nutrition(self):
        estimate = main.estimate_nutrition(
            [{"items": ["1 cup mystery ingredient"]}], servings=1
        )
        self.assertEqual(estimate["calories"], 0)
        self.assertEqual(estimate["breakdown"], [])


class DirectionQualityTests(unittest.TestCase):
    def test_empty_delimiters_are_removed_from_recipe_directions(self):
        output = main._validated_directions([
            "Combine eggs () cocoa powder [ ] and sugar.",
            "Add { } vanilla.",
        ])
        self.assertEqual(output, [
            "Combine eggs cocoa powder and sugar.",
            "Add vanilla.",
        ])

    def test_dangling_container_is_joined_to_following_action(self):
        output = main._validated_directions([
            "In a mixing bowl",
            "Combine eggs and cocoa powder until smooth.",
        ])
        self.assertEqual(output, [
            "In a mixing bowl, combine eggs and cocoa powder until smooth.",
        ])


if __name__ == "__main__":
    unittest.main()
