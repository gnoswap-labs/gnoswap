import unittest

from analyze_results import analyze


class AnalyzeResultsTest(unittest.TestCase):
    def test_calculates_timing_percentiles(self):
        blocks = [
            {"execute_block_us": execute, "commit_total_us": commit}
            for execute, commit in [(100, 10), (200, 20), (300, 30), (400, 40), (500, 50)]
        ]

        self.assertEqual(
            analyze(blocks),
            {
                "blocks": 5,
                "metrics": {
                    "execute_block_us": {"p50": 300, "p95": 480, "p99": 496},
                    "commit_total_us": {"p50": 30, "p95": 48, "p99": 49.6},
                    "exec_commit_us": {"p50": 330, "p95": 528, "p99": 545.6},
                },
            },
        )

    def test_summarizes_gas_utilization_and_price(self):
        result = analyze(
            [
                {"gas_used": 50, "max_gas": 100, "gas_price_ratio": 1.0},
                {"gas_used": 70, "max_gas": 100, "gas_price_ratio": 2.0},
            ]
        )

        self.assertEqual(result["metrics"]["block_gas_utilization_pct"]["avg"], 60.0)
        self.assertEqual(result["metrics"]["gas_price_ratio"], {"avg": 1.5, "max": 2.0})


if __name__ == "__main__":
    unittest.main()
