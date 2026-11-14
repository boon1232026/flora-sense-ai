from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from flora_ai.fusion import fuse
from flora_ai.image_processing import analyze_rgb_pixels
from flora_ai.sensor_analysis import analyze_sensor_window
from flora_ai.types import SensorSnapshot


class ImageAnalysisTest(unittest.TestCase):
    def test_green_pixels(self):
        metrics = analyze_rgb_pixels([[50, 160, 60]] * 20)
        self.assertTrue(metrics.quality_ok)
        self.assertGreater(metrics.green_ratio, 0.9)
        self.assertGreater(metrics.exg, 0.4)


class SensorFusionTest(unittest.TestCase):
    def test_dry_and_hot_leaf_is_high_risk(self):
        readings = [
            SensorSnapshot(45, 30, 60, 31),
            SensorSnapshot(35, 31, 59, 33),
            SensorSnapshot(24, 32, 58, 37),
        ]
        result = fuse(analyze_sensor_window(readings))
        self.assertEqual(result.risk_level, "HIGH")
        self.assertGreaterEqual(result.risk_score, 70)

    def test_missing_sensor_never_low(self):
        result = fuse(analyze_sensor_window([SensorSnapshot(None, None, None, None)]))
        self.assertEqual(result.risk_level, "MEDIUM")
        self.assertIn("sensor_missing", result.features)


if __name__ == "__main__":
    unittest.main()
