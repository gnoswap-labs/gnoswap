package fuzzing

import (
	"testing"
)

// Config configures the property-based test execution.
type Config struct {
	// BaseSeed is the base seed for PRNG initialization.
	// If 0, a random seed is used.
	BaseSeed uint64

	// Iterations is the number of test cases to generate.
	// Default is 100.
	Iterations int

	// Verbose enables verbose output.
	Verbose bool
}

// Check runs property-based test with default configuration.
// The property function receives *T which provides access to generators.
//
// Example:
//
//	fuzzing.Check(t, func(ft *fuzzing.T) {
//	    x := ft.IntRange(0, 100)
//	    if x < 0 || x > 100 {
//	        ft.Fatalf("x out of range: %d", x)
//	    }
//	})
func Check(t *testing.T, property func(*T)) {
	CheckWithConfig(t, nil, property)
}

// CheckWithConfig runs property-based test with custom configuration.
func CheckWithConfig(t *testing.T, cfg *Config, property func(*T)) {
	if cfg == nil {
		cfg = &Config{}
	}
	if cfg.Iterations == 0 {
		cfg.Iterations = 100
	}

	baseSeed := cfg.BaseSeed
	if baseSeed == 0 {
	    baseSeed = BASE_SEED
	}

	for i := 0; i < cfg.Iterations; i++ {
		seed := baseSeed + uint64(i)
		ft := newT(seed, cfg.Verbose)

		// Run the property
		func() {
			defer func() {
				if r := recover(); r != nil {
					// Check if it's an invalidData error (generation failure)
					if err, ok := r.(invalidData); ok {
						// Invalid data means we couldn't generate a valid value
						// This is not a test failure, just skip this iteration
						if cfg.Verbose {
							t.Logf("Iteration %d: skipped due to invalid data: %v", i, err)
						}
						return
					}

					// Check if it's a test failure
					if err, ok := r.(*testFailure); ok {
						// Test failed - report with seed for reproduction
						t.Errorf("Iteration %d failed (seed=%d): %s", i, seed, err.msg)

						// TODO: Implement shrinking
						// For now, just report the original failure
						return
					}

					// Other panic - re-panic
					panic(r)
				}
			}()

			property(ft)
		}()
	}
}

// T provides access to generators during property-based testing.
// It wraps a bitstream and provides convenience methods.
type T struct {
	s       bitStream
	verbose bool
	tb      *testing.T
}

// newT creates a new T with the given seed.
func newT(seed uint64, verbose bool) *T {
	return &T{
		s:       newRandomBitStream(seed, true),
		verbose: verbose,
	}
}

// testFailure represents a test failure with message.
type testFailure struct {
	msg string
}

// Fatalf fails the test with a formatted message.
func (t *T) Fatalf(format string, args ...interface{}) {
	panic(&testFailure{
		msg: sprintf(format, args...),
	})
}

// Errorf records an error but doesn't stop execution.
// For now, it's equivalent to Fatalf.
func (t *T) Errorf(format string, args ...interface{}) {
	t.Fatalf(format, args...)
}

// Logf logs a formatted message.
func (t *T) Logf(format string, args ...interface{}) {
	if t.verbose {
		// In verbose mode, would log to output
		// For now, no-op
	}
}

// Helper marks the calling function as a test helper.
// This is a no-op in Gno but kept for API compatibility.
func (t *T) Helper() {
	// No-op in Gno
}

// Draw generates a value from the given generator.
func (t *T) Draw(gen *Generator) any {
	return gen.value(t)
}
