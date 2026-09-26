#!/usr/bin/env python3
import unittest

from PIL import Image

import compare


class CompareGeometryTests(unittest.TestCase):
    def test_rejects_resized_replica(self) -> None:
        reference = Image.new("RGB", (2400, 1600))
        replica = Image.new("RGB", (1200, 800))
        with self.assertRaisesRegex(ValueError, "capture size mismatch"):
            compare.validate_capture_geometry(reference, replica)


if __name__ == "__main__":
    unittest.main()
