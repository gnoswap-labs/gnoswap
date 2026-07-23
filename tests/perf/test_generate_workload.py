import unittest

from generate_workload import generate


class GenerateWorkloadTest(unittest.TestCase):
    def test_preserves_representative_mix_across_twenty_operations(self):
        source = generate(start=0, count=20)

        self.assertEqual(source.count("ExactInSingleSwapRoute"), 14)
        self.assertEqual(source.count("IncreaseLiquidity"), 3)
        self.assertEqual(source.count("DecreaseLiquidity"), 2)
        self.assertEqual(source.count("CollectFee"), 1)

    def test_rotates_the_mix_between_blocks(self):
        first = generate(start=0, count=10)
        second = generate(start=10, count=10)

        combined = first + second
        self.assertEqual(combined.count("ExactInSingleSwapRoute"), 14)
        self.assertEqual(combined.count("IncreaseLiquidity"), 3)
        self.assertEqual(combined.count("DecreaseLiquidity"), 2)
        self.assertEqual(combined.count("CollectFee"), 1)

    def test_preserves_swap_direction_across_split_generation(self):
        continuous_last = [
            line for line in generate(start=0, count=5).splitlines()
            if "ExactInSingleSwapRoute" in line
        ][-1]
        split = generate(start=4, count=1)

        self.assertIn(continuous_last, split)


if __name__ == "__main__":
    unittest.main()
