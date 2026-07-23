import unittest

from calibrate_workload import calibrate


class CalibrateWorkloadTest(unittest.TestCase):
    def test_converts_template_gas_to_operations_per_load(self):
        self.assertEqual(
            calibrate([(20, 700_000_000), (80, 2_500_000_000)], max_gas=3_000_000_000),
            {
                "calibration_points": [
                    {"operations": 20, "gas_used": 700_000_000},
                    {"operations": 80, "gas_used": 2_500_000_000},
                ],
                "fixed_gas": 100_000_000,
                "gas_per_operation": 30_000_000,
                "max_gas": 3_000_000_000,
                "operations_per_block": {"50": 46, "70": 66, "100": 96},
            },
        )


if __name__ == "__main__":
    unittest.main()
