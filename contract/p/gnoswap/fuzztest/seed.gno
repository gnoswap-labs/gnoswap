package fuzztest

import (
	"time"
)

// SeedManager helps generate unique seeds for tests
//
// Note:
// The original fuzztest implementation used a fixed seed (987654321) in initRNG,
// which caused all generators to produce the same sequence of values. This was
// problematic for fuzz testing as it reduced test coverage and made it impossible
// to find edge cases through randomization.
//
// SeedManager provides a way for test code to manage its own seeds without
// relying on global state. Each test creates its own SeedManager instance,
// which uses time-based initialization for uniqueness and a counter with
// prime multiplication for generating diverse seeds for multiple generators
// within the same test.
type SeedManager struct {
	baseSeed uint64
	counter  uint64
}

// NewSeedManager creates a new seed manager with time-based initial seed
func NewSeedManager() *SeedManager {
	return &SeedManager{
		baseSeed: uint64(time.Now().UnixNano()),
		counter:  0,
	}
}

// NewSeedManagerWithSeed creates a seed manager with a specific base seed (for reproducible tests)
func NewSeedManagerWithSeed(seed uint64) *SeedManager {
	return &SeedManager{
		baseSeed: seed,
		counter:  0,
	}
}

// NextSeed returns the next unique seed
func (sm *SeedManager) NextSeed() uint64 {
	sm.counter++
	// Use a prime multiplier (2654435761) to ensure good distribution
	// This prime is commonly used in hash functions for its excellent
	// distribution properties when combined with modulo operations
	return sm.baseSeed + sm.counter*2654435761
}

// CreateIntGenerator creates an IntGenerator with a unique seed
func (sm *SeedManager) CreateIntGenerator(min, max int) Generator {
	return IntRangeWithSeed(min, max, sm.NextSeed())
}

// CreateUint32Generator creates a Uint32Generator with a unique seed
func (sm *SeedManager) CreateUint32Generator(min, max uint32) Generator {
	return Uint32RangeWithSeed(min, max, sm.NextSeed())
}

// CreateBoolGenerator creates a BoolGenerator with a unique seed
func (sm *SeedManager) CreateBoolGenerator() Generator {
	return BoolWithSeed(sm.NextSeed())
}

// CreateStringGenerator creates a StringGenerator with a unique seed
func (sm *SeedManager) CreateStringGenerator(minLen, maxLen int) Generator {
	return StringWithSeed(minLen, maxLen, sm.NextSeed())
}
