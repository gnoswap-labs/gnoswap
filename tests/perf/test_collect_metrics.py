import unittest

from collect_metrics import parse_gnokey_output


class ParseGnokeyOutputTest(unittest.TestCase):
    def test_returns_last_transaction_metrics(self):
        output = """
GAS USED:       100
STORAGE DELTA:  20 bytes
STORAGE FEE:    30ugnot
TOTAL TX COST:  40ugnot
GAS USED:       500
STORAGE DELTA:  -60 bytes
STORAGE FEE:    70ugnot
TOTAL TX COST:  80ugnot
"""

        self.assertEqual(
            parse_gnokey_output(output),
            {
                "gas_used": 500,
                "storage_delta": -60,
                "storage_fee": 70,
                "total_cost": "80ugnot",
            },
        )

    def test_does_not_mix_optional_metrics_between_transactions(self):
        output = """
GAS USED:       100
STORAGE FEE:    30ugnot
GAS USED:       500
TOTAL TX COST:  80ugnot
"""

        self.assertEqual(parse_gnokey_output(output)["storage_fee"], None)


if __name__ == "__main__":
    unittest.main()
