"""Keep ordinary-device UI identical to the explicitly pinned upstream release."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Upstream jxxghp/MoviePilot-App 49a0b049f74bd0f480de243e22623f23317af8b0.
# Update these only when intentionally upgrading the original UI from upstream.
UPSTREAM_HASHES = {
    "ShellController.swift": "2b043ddeb32b40bb8b2d3d6c120bb1427c5b6ff60a3ecd0d2dfa27c3c9fdabed",
    "BottomNavigationView.swift": "5ff1aeefea4fcfa4f2940b502235a153d4186a5ca9a21e28b1e8fb40c03d5410",
}


class OriginalShellIsolationTests(unittest.TestCase):
    def test_original_navigation_matches_upstream(self):
        for name, expected in UPSTREAM_HASHES.items():
            with self.subTest(file=name):
                actual = hashlib.sha256((ROOT / "ios" / "MoviePilot" / name).read_bytes()).hexdigest()
                self.assertEqual(actual, expected, "Make Duo-only changes in ios/MoviePilot/Duo instead.")
