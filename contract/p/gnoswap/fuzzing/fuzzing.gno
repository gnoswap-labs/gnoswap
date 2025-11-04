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
		// In real implementation, use time-based seed or from environment
		// For now, use a fixed seed for determinism
		baseSeed = 1
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
						t.Errorf("Iteration %d failed (seed=%d): %s\n%s", i, seed, err.msg, err.trace)

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

// testFailure represents a test failure with message and trace.
type testFailure struct {
	msg   string
	trace string
}

// Fatalf fails the test with a formatted message.
func (t *T) Fatalf(format string, args ...interface{}) {
	panic(&testFailure{
		msg:   sprintf(format, args...),
		trace: "", // TODO: Capture stack trace
	})
}

// Errorf records an error but doesn't stop execution.
// For now, it's equivalent to Fatalf.
func (t *T) Errorf(format string, args ...interface{}) {
	t.Fatalf(format, args...)
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

// IntRange generates an int in [min, max].
func (t *T) IntRange(min, max int) int {
	return IntRange(min, max).value(t).(int)
}

// Int64Range generates an int64 in [min, max].
func (t *T) Int64Range(min, max int64) int64 {
	return Int64Range(min, max).value(t).(int64)
}

// UintRange generates a uint in [min, max].
func (t *T) UintRange(min, max uint) uint {
	return UintRange(min, max).value(t).(uint)
}

// Uint64Range generates a uint64 in [min, max].
func (t *T) Uint64Range(min, max uint64) uint64 {
	return Uint64Range(min, max).value(t).(uint64)
}

// Bool generates a boolean.
func (t *T) Bool() bool {
	return Bool().value(t).(bool)
}

// Byte generates a byte.
func (t *T) Byte() byte {
	return Byte().value(t).(byte)
}

// ByteRange generates a byte in [min, max].
func (t *T) ByteRange(min, max byte) byte {
	return ByteRange(min, max).value(t).(byte)
}

// String generates a string.
func (t *T) String() string {
	return String().value(t).(string)
}

// StringN generates a string with length in [minLen, maxLen].
func (t *T) StringN(minLen, maxLen int) string {
	return StringN(minLen, maxLen).value(t).(string)
}

// Rune generates a rune.
func (t *T) Rune() rune {
	return Rune().value(t).(rune)
}

// RuneRange generates a rune in [min, max].
func (t *T) RuneRange(min, max rune) rune {
	return RuneRange(min, max).value(t).(rune)
}

// SliceOf generates a slice using the given element generator.
func (t *T) SliceOf(elemGen *Generator) []any {
	return SliceOf(elemGen).value(t).([]any)
}

// SliceOfN generates a slice with length in [minLen, maxLen].
func (t *T) SliceOfN(elemGen *Generator, minLen, maxLen int) []any {
	return SliceOfN(elemGen, minLen, maxLen).value(t).([]any)
}

// MapOf generates a map using key and value generators.
func (t *T) MapOf(keyGen, valueGen *Generator) map[any]any {
	return MapOf(keyGen, valueGen).value(t).(map[any]any)
}

// MapOfN generates a map with size in [minSize, maxSize].
func (t *T) MapOfN(keyGen, valueGen *Generator, minSize, maxSize int) map[any]any {
	return MapOfN(keyGen, valueGen, minSize, maxSize).value(t).(map[any]any)
}

// Permutation generates a permutation of the given slice.
func (t *T) Permutation(slice []any) []any {
	return Permutation(slice).value(t).([]any)
}

// SampledFrom randomly selects from the given slice.
func (t *T) SampledFrom(slice []any) any {
	return SampledFrom(slice).value(t)
}

// OneOf randomly selects one of the given generators.
func (t *T) OneOf(gens ...*Generator) any {
	return OneOf(gens...).value(t)
}

// Repeat executes a function multiple times with varying count.
// The function should return false to reject an iteration.
//
// Example:
//
//	ft.Repeat(1, 10, func() bool {
//	    x := ft.IntRange(0, 100)
//	    return x > 0  // Reject zeros
//	})
func (t *T) Repeat(minCount, maxCount int, fn func() bool) {
	r := newRepeat(minCount, maxCount, -1, "repeat")
	for r.more(t.s) {
		if !fn() {
			r.reject()
		}
	}
}

// RepeatAvg executes a function with a target average count.
func (t *T) RepeatAvg(minCount, maxCount int, avgCount float64, fn func() bool) {
	r := newRepeat(minCount, maxCount, avgCount, "repeat")
	for r.more(t.s) {
		if !fn() {
			r.reject()
		}
	}
}
