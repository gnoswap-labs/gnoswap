package fuzzing

import (
	"testing"
	"time"
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
		// Use time-based seed for randomized testing
		// Note: In Gno test environment, time.Now() is fixed to first block timestamp,
		// so tests will be deterministic. In production/real blockchain, each block
		// has a different timestamp, enabling true randomization.
		baseSeed = uint64(time.Now().UnixNano())
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

// Int8Range generates an int8 in [min, max].
func (t *T) Int8Range(min, max int8) int8 {
	return Int8Range(min, max).value(t).(int8)
}

// Int16Range generates an int16 in [min, max].
func (t *T) Int16Range(min, max int16) int16 {
	return Int16Range(min, max).value(t).(int16)
}

// Int32Range generates an int32 in [min, max].
func (t *T) Int32Range(min, max int32) int32 {
	return Int32Range(min, max).value(t).(int32)
}

// Uint8Range generates a uint8 in [min, max].
func (t *T) Uint8Range(min, max uint8) uint8 {
	return Uint8Range(min, max).value(t).(uint8)
}

// Uint16Range generates a uint16 in [min, max].
func (t *T) Uint16Range(min, max uint16) uint16 {
	return Uint16Range(min, max).value(t).(uint16)
}

// Uint32Range generates a uint32 in [min, max].
func (t *T) Uint32Range(min, max uint32) uint32 {
	return Uint32Range(min, max).value(t).(uint32)
}

// Float32Range generates a float32 in [min, max].
func (t *T) Float32Range(min, max float32) float32 {
	return Float32Range(min, max).value(t).(float32)
}

// Float64Range generates a float64 in [min, max].
func (t *T) Float64Range(min, max float64) float64 {
	return Float64Range(min, max).value(t).(float64)
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

// SliceOfDistinct generates a slice with distinct elements.
func (t *T) SliceOfDistinct(elemGen *Generator, keyFn func(any) any) []any {
	return SliceOfDistinct(elemGen, keyFn).value(t).([]any)
}

// SliceOfNDistinct generates a slice with distinct elements and length bounds.
func (t *T) SliceOfNDistinct(elemGen *Generator, minLen, maxLen int, keyFn func(any) any) []any {
	return SliceOfNDistinct(elemGen, minLen, maxLen, keyFn).value(t).([]any)
}

// StringOf generates a string from custom rune generator.
func (t *T) StringOf(runeGen *Generator) string {
	return StringOf(runeGen).value(t).(string)
}

// StringOfN generates a string from custom rune generator with length bounds.
func (t *T) StringOfN(runeGen *Generator, minLen, maxLen int) string {
	return StringOfN(runeGen, minLen, maxLen).value(t).(string)
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
