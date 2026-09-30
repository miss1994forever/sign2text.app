import importlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class ConfigDefaultsTest(unittest.TestCase):
    def test_csl_waitk_pair_is_preferred(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            slt = root / "SLRT/Online/SLT"
            waitk = slt / "results/g2t_wait2_csl_retrain_k2_20260920/ckpts/csl_best.ckpt"
            standard = root / "models/checkpoints/online_slrt/csl_daily_g2t_best.ckpt"
            waitk.parent.mkdir(parents=True)
            standard.parent.mkdir(parents=True)
            waitk.touch()
            standard.touch()
            environment = {
                "WORKSPACE_ROOT": str(root),
                "SLRT_ROOT": str(root / "SLRT"),
                "SLRT_SLT_ROOT": str(slt),
                "SLRT_DATASET_PRESET": "csl-daily",
            }
            with patch.dict(os.environ, environment, clear=True):
                config = importlib.import_module("app.config")
                self.assertEqual(config._default_slt_checkpoint(), str(waitk))
                self.assertEqual(
                    config._default_slt_config(),
                    slt / "configs/g2t_wait2_csl_retrain_k2_20260920.yaml",
                )
                self.assertTrue(config._default_enable_slt())

    def test_explicit_standard_checkpoint_selects_standard_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            slt = root / "SLRT/Online/SLT"
            checkpoint = root / "custom/model.ckpt"
            environment = {
                "WORKSPACE_ROOT": str(root),
                "SLRT_ROOT": str(root / "SLRT"),
                "SLRT_SLT_ROOT": str(slt),
                "SLRT_DATASET_PRESET": "csl-daily",
                "SLRT_SLT_CHECKPOINT": str(checkpoint),
            }
            with patch.dict(os.environ, environment, clear=True):
                config = importlib.import_module("app.config")
                self.assertEqual(config._default_slt_config(), slt / "configs/g2t_csl.yaml")


if __name__ == "__main__":
    unittest.main()
