package fuzz

import (
	"time"
)

// SeedManager manages unique seed generation for fuzz testing.
// Each instance maintains its own seed sequence, avoiding global state issues
// and ensuring diverse random sequences across different generators.
type SeedManager struct {
	baseSeed uint64
	counter  uint64
}

// NewSeedManager creates a new seed manager with time-based initial seed.
func NewSeedManager() *SeedManager {
	return &SeedManager{
		baseSeed: uint64(time.Now().UnixNano()),
		counter:  0,
	}
}

// NewSeedManagerWithSeed creates a seed manager with the specified base seed for reproducible tests.
func NewSeedManagerWithSeed(seed uint64) *SeedManager {
	return &SeedManager{
		baseSeed: seed,
		counter:  0,
	}
}

// NextSeed returns the next unique seed value using prime multiplier 2654435761 for good distribution.
func (sm *SeedManager) NextSeed() uint64 {
	sm.counter++
	return sm.baseSeed + sm.counter*2654435761
}

// CreateIntGenerator creates an IntGenerator with a unique seed.
func (sm *SeedManager) CreateIntGenerator(min, max int) Generator {
	return IntRangeWithSeed(min, max, sm.NextSeed())
}

// CreateUint32Generator creates a Uint32Generator with a unique seed.
func (sm *SeedManager) CreateUint32Generator(min, max uint32) Generator {
	return Uint32RangeWithSeed(min, max, sm.NextSeed())
}

// CreateBoolGenerator creates a BoolGenerator with a unique seed.
func (sm *SeedManager) CreateBoolGenerator() Generator {
	return BoolWithSeed(sm.NextSeed())
}

// CreateStringGenerator creates a StringGenerator with a unique seed.
func (sm *SeedManager) CreateStringGenerator(minLen, maxLen int) Generator {
	return StringWithSeed(minLen, maxLen, sm.NextSeed())
}
