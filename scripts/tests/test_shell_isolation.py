"""Keep ordinary-device UI identical to the explicitly pinned upstream release."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Upstream jxxghp/MoviePilot-App aee8fc31ef29ad36a5833529df1f71b95fe8e41f.
# Update these only when intentionally upgrading the original UI from upstream.
UPSTREAM_HASHES = {
    "ShellController.swift": "4d9e9475c2c875fc987ec94a38d60926ee06112dcd7f906c4a7bbe2c2b81abb6",
    "BottomNavigationView.swift": "ef33236631f62368e4b2e837a677b03ee5422b425912bbbdd7e1506ff127b247",
}


class OriginalShellIsolationTests(unittest.TestCase):
    def test_original_navigation_matches_upstream(self):
        for name, expected in UPSTREAM_HASHES.items():
            with self.subTest(file=name):
                actual = hashlib.sha256((ROOT / "ios" / "MoviePilot" / name).read_bytes()).hexdigest()
                self.assertEqual(actual, expected, "Make Duo-only changes in ios/MoviePilot/Duo instead.")
