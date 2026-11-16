"""Keep ordinary-device UI identical to the explicitly pinned upstream release."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
# Upstream jxxghp/MoviePilot-App f72877f5722e499e17de38f5db064b11cff54a18.
# Update these only when intentionally upgrading the original UI from upstream.
UPSTREAM_HASHES = {
    "ShellController.swift": "6e9985f99d2a28220d334035ca8e90d05b38c6e59b6212939f357a2de83d8e74",
    "BottomNavigationView.swift": "b6b83613f6f09655f2a35152b6abadc682430cf5986a05751e5a275e867b3a76",
}


class OriginalShellIsolationTests(unittest.TestCase):
    def test_original_navigation_matches_upstream(self):
        for name, expected in UPSTREAM_HASHES.items():
            with self.subTest(file=name):
                actual = hashlib.sha256((ROOT / "ios" / "MoviePilot" / name).read_bytes()).hexdigest()
                self.assertEqual(actual, expected, "Make Duo-only changes in ios/MoviePilot/Duo instead.")
