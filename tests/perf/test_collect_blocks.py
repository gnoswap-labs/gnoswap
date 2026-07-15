import json
import tempfile
import unittest
from pathlib import Path

from collect_blocks import collect_blocks


class CollectBlocksTest(unittest.TestCase):
    def test_joins_node_events_by_height_and_preserves_fields(self):
        events = [
            {"msg": "Committed state", "Node": {"height": 2, "mempool_txs_after": 0}},
            {"msg": "noise", "height": 2},
            {"msg": "Executed block", "Node": {"height": 1, "block_txs": 1}},
            {"msg": "Updated block gas price", "Node": {"height": 1, "gas_used": 42, "new_price_amount": 3}},
            {"msg": "Committed state", "Node": {"height": 1, "commit_total_us": 9}},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "node.jsonl"
            source.write_text("runtime noise\n" + "\n".join(json.dumps(event) for event in events) + "\n")

            self.assertEqual(
                collect_blocks(source),
                [
                    {
                        "height": 1,
                        "execution": events[2],
                        "commit": events[4],
                        "gas_price": events[3],
                    },
                    {"height": 2, "commit": events[0]},
                ],
            )


if __name__ == "__main__":
    unittest.main()
