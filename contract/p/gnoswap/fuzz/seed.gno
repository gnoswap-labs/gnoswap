package fuzz

const BASE_SEED = 0

// baseSeed returns the package's fixed default seed.
//
// Returns:
//   - seed: The constant BASE_SEED value, currently zero.
func baseSeed() uint64 {
	return BASE_SEED
}
