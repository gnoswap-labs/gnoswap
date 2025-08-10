// Package fuzz provides property-based testing utilities for generating random test data.
// It supports various data types including integers, strings, and 256-bit numbers,
// with configurable ranges and boundary value testing.
package fuzz

import (
	"errors"
	"math"
	"math/rand"
	"strconv"
	"unicode/utf8"

	xs "gno.land/p/wyhaines/rand/xorshift64star"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	MAX_UINT64  string = "18446744073709551615"
	MAX_INT128  string = "170141183460469231731687303715884105727"
	MAX_UINT128 string = "340282366920938463463374607431768211455"
)

// Generator is the interface that wraps the basic Generate method.
// Implementations return randomly generated values of their specific type.
type Generator interface {
	Generate() any
}

// seedCounter ensures different seeds for each generator instance.
// We use a function-scoped approach to avoid realm modification issues.
var seedCounter uint64

// getNextSeed returns a new seed value for RNG initialization.
// It uses a counter with a prime multiplier to ensure uniqueness.
func getNextSeed() uint64 {
	// Increment counter and combine with time for uniqueness
	seedCounter++
	// Use a prime multiplier to spread values
	return seedCounter * 2654435761
}

// initRNG initializes the random number generator if not already initialized.
func initRNG(rng **xs.Xorshift64Star) {
	if *rng == nil {
		// Use entropy-based seed to avoid realm issues
		*rng = xs.New()
	}
}

// TODO: add more generators
var (
	_ Generator = (*IntGenerator)(nil)
	_ Generator = (*Uint32Generator)(nil)
	_ Generator = (*NumberStringGenerator)(nil)
)

// IntGenerator generates random integers within a specified range.
// The zero value generates full int32 range values.
type IntGenerator struct {
	min, max int
	rng      *xs.Xorshift64Star
}

// Generate returns a random integer within the generator's range.
func (g *IntGenerator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return int(int32(g.rng.Uint64()))
	}
	size := uint64(g.max - g.min + 1)
	return int(g.rng.Uint64()%size) + g.min
}

// IntRange creates an IntGenerator that produces values between min and max inclusive.
func IntRange(min, max int) Generator {
	return &IntGenerator{
		min: min,
		max: max,
		rng: nil, // Will be initialized on first use
	}
}

// IntRangeWithSeed creates an IntGenerator with the specified seed for reproducible generation.
func IntRangeWithSeed(min, max int, seed uint64) Generator {
	return &IntGenerator{
		min: min,
		max: max,
		rng: xs.New(seed),
	}
}

// Uint32Generator generates random uint32 values within a specified range.
// The zero value generates full uint32 range values.
type Uint32Generator struct {
	min, max uint32
	rng      *xs.Xorshift64Star
}

// Generate returns a random uint32 within the generator's range.
func (g *Uint32Generator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return uint32(g.rng.Uint64())
	}
	size := uint64(g.max - g.min + 1)
	return uint32(g.rng.Uint64()%size) + g.min
}

// Uint32Range creates a Uint32Generator that produces values between min and max inclusive.
func Uint32Range(min, max uint32) Generator {
	return &Uint32Generator{
		min: min,
		max: max,
		rng: nil, // Will be initialized on first use
	}
}

// Uint32RangeWithSeed creates a Uint32Generator with the specified seed for reproducible generation.
func Uint32RangeWithSeed(min, max uint32, seed uint64) Generator {
	return &Uint32Generator{
		min: min,
		max: max,
		rng: xs.New(seed),
	}
}

// Uint32 creates a Uint32Generator that produces values between 0 and 100.
func Uint32() Generator {
	return Uint32Range(0, 100)
}

// BoolGenerator generates random boolean values.
type BoolGenerator struct {
	rng *xs.Xorshift64Star
}

// Generate returns a random boolean value.
func (g *BoolGenerator) Generate() any {
	initRNG(&g.rng)
	return g.rng.Uint64()%2 == 0
}

// Bool creates a BoolGenerator that produces random boolean values.
func Bool() Generator {
	return &BoolGenerator{rng: nil} // Will be initialized on first use
}

// BoolWithSeed creates a BoolGenerator with the specified seed for reproducible generation.
func BoolWithSeed(seed uint64) Generator {
	return &BoolGenerator{rng: xs.New(seed)}
}

// StringGenerator generates random ASCII strings within a specified length range.
type StringGenerator struct {
	minLen, maxLen int
	rng            *xs.Xorshift64Star
}

// Generate returns a random ASCII string within the generator's length range.
func (g *StringGenerator) Generate() interface{} {
	initRNG(&g.rng)
	if g.maxLen == 0 {
		g.maxLen = 10
	}
	lengthRange := uint64(g.maxLen - g.minLen + 1)
	length := int(g.rng.Uint64()%lengthRange) + g.minLen
	result := make([]byte, length)
	for i := range result {
		result[i] = byte(g.rng.Uint64()%94 + 33)
	}
	return string(result)
}

// StringWithSeed creates a StringGenerator with the specified seed for reproducible generation.
func StringWithSeed(minLen, maxLen int, seed uint64) Generator {
	return &StringGenerator{
		minLen: minLen,
		maxLen: maxLen,
		rng:    xs.New(seed),
	}
}

// NumberStringGenerator generates numeric strings in various bases (binary, octal, decimal, hex).
type NumberStringGenerator struct {
	min, max  int64
	baseTypes []int
	rng       *xs.Xorshift64Star
}

// Generate returns a numeric string in a random base format (binary, octal, decimal, or hexadecimal).
func (g *NumberStringGenerator) Generate() any {
	initRNG(&g.rng)

	if g.min == 0 && g.max == 0 {
		g.max = 1000000
	}

	size := uint64(g.max - g.min + 1)
	value := int64(g.rng.Uint64()%size) + g.min

	if len(g.baseTypes) == 0 {
		g.baseTypes = []int{2, 8, 10, 16}
	}

	baseIndex := g.rng.Uint64() % uint64(len(g.baseTypes))
	base := g.baseTypes[baseIndex]

	switch base {
	case 2:
		return "0b" + strconv.FormatInt(value, 2)
	case 8:
		return "0o" + strconv.FormatInt(value, 8)
	case 16:
		return "0x" + strconv.FormatInt(value, 16)
	default:
		return strconv.FormatInt(value, 10)
	}
}

// NumberString creates a NumberStringGenerator with default range (0-1000000) and all base formats.
func NumberString() Generator {
	return &NumberStringGenerator{
		min:       0,
		max:       1000000,
		baseTypes: []int{2, 8, 10, 16},
		rng:       nil, // Will be initialized on first use
	}
}

// NumberStringRange creates a NumberStringGenerator with the specified range and base formats.
func NumberStringRange(min, max int64, bases ...int) Generator {
	if len(bases) == 0 {
		bases = []int{2, 8, 10, 16}
	}
	return &NumberStringGenerator{
		min:       min,
		max:       max,
		baseTypes: bases,
		rng:       nil, // Will be initialized on first use
	}
}

// Config controls fuzzing parameters for property-based testing.
type Config struct {
	Iterations int
	Shrink     bool
	Seed       uint64 // Optional: if provided, uses this seed for reproducibility
}

// Result contains the outcome of a fuzzing run.
type Result struct {
	Failed       bool
	FailingInput any
	Iterations   int
}

// abs returns the absolute value of x.
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

// shrinkInt attempts to find a simpler failing input through iterative shrinking.
func shrinkInt(property func(int) bool, failingInput int) int {
	current := failingInput
	for attempt := 0; attempt < 100; attempt++ {
		candidates := []int{0, 1, -1, current / 2, current - 1, current + 1}
		for _, candidate := range candidates {
			if !property(candidate) && abs(candidate) <= abs(current) {
				current = candidate
			}
		}
	}
	return current
}

// GenerateBoundary returns boundary values for the specified type.
// Supported types: "int", "uint", "string", "numberString", "slice".
func GenerateBoundary(vt string) []any {
	switch vt {
	case "int":
		return []any{
			0, 1, -1,
			int(math.MaxInt), int(math.MinInt),
			int(math.MaxInt - 1), int(math.MinInt + 1),
		}
	case "uint":
		return []any{
			uint(0), uint(1),
			uint(math.MaxUint), uint(math.MaxUint - 1),
		}
	case "string":
		return []any{
			"", " ", "\n", "\t",
			"a", "A", "0",
			generateLongString(100),
			generateUnicodeString(),
		}
	case "numberString":
		return []any{
			"0", "1", "-1",
			"0b0", "0b1", "0b1111111111111111",
			"0o0", "0o7", "0o777",
			"0x0", "0x1", "0xFFFF", "0xffffffff",
			"9223372036854775807", "-9223372036854775808",
		}
	case "slice":
		return []any{
			[]int{},
			generateLargeSlice(10000),
		}
	}
	return nil
}

// generateLongString creates a string of 'a' characters with the specified length.
func generateLongString(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = 'a'
	}
	return string(b)
}

// generateUnicodeString creates a string containing various Unicode characters including Greek, CJK, and emoji.
func generateUnicodeString() string {
	runes := []rune{'α', 'β', 'γ', '漢', '字', '🌟'}
	result := ""
	for _, r := range runes {
		if utf8.ValidRune(r) {
			result += string(r)
		}
	}
	return result
}

// generateLargeSlice creates a slice of n random integers between 0 and 99.
func generateLargeSlice(n int) []int {
	slice := make([]int, n)
	for i := 0; i < n; i++ {
		slice[i] = rand.IntN(100)
	}
	return slice
}

// Uint256Generator generates random uint256 values for testing.
type Uint256Generator struct {
	allowZero bool
	maxBits   uint
	seedMgr   *SeedManager
}

// NewUint256Generator creates a new Uint256Generator with the specified zero-allowance and bit constraints.
func NewUint256Generator(allowZero bool, maxBits uint) *Uint256Generator {
	return &Uint256Generator{
		allowZero: allowZero,
		maxBits:   maxBits,
		seedMgr:   NewSeedManager(),
	}
}

// Generate returns a random uint256 value according to the generator's constraints.
// Returns special values (zero, one, MAX_UINT128, MAX_INT128, MAX_UINT64) or random values within maxBits.
func (g *Uint256Generator) Generate() any {
	if g.seedMgr == nil {
		g.seedMgr = NewSeedManager()
	}

	// Generate special cases
	specialCase := g.seedMgr.CreateIntGenerator(0, 10).Generate().(int)
	switch specialCase {
	case 0:
		if g.allowZero {
			return u256.Zero()
		}
	case 1:
		return u256.One()
	case 2:
		// MAX_UINT128
		return u256.MustFromDecimal(MAX_UINT128)
	case 3:
		val := u256.MustFromDecimal(MAX_UINT128)
		return new(u256.Uint).Add(val, u256.One())
	case 4:
		return u256.MustFromDecimal(MAX_INT128)
	case 5:
		return u256.MustFromDecimal(MAX_UINT64)
	}

	// random value within maxBits
	bits := g.seedMgr.CreateIntGenerator(1, int(g.maxBits)).Generate().(int)
	val := u256.One()
	val = new(u256.Uint).Lsh(val, uint(bits))

	offset := g.seedMgr.CreateIntGenerator(0, 1000).Generate().(int)
	val = new(u256.Uint).Add(val, u256.NewUint(uint64(offset)))

	return val
}

// Int256Generator generates random int256 values for testing.
type Int256Generator struct {
	allowZero     bool
	allowNegative bool
	maxBits       uint
	seedMgr       *SeedManager
}

// NewInt256Generator creates a new Int256Generator with the specified zero, negative, and bit constraints.
func NewInt256Generator(allowZero bool, allowNegative bool, maxBits uint) *Int256Generator {
	return &Int256Generator{
		allowZero:     allowZero,
		allowNegative: allowNegative,
		maxBits:       maxBits,
		seedMgr:       NewSeedManager(),
	}
}

// Generate returns a random int256 value according to the generator's constraints.
// Returns special values or random positive/negative values within maxBits range.
func (g *Int256Generator) Generate() any {
	if g.seedMgr == nil {
		g.seedMgr = NewSeedManager()
	}

	specialCase := g.seedMgr.CreateIntGenerator(0, 10).Generate().(int)
	switch specialCase {
	case 0:
		if g.allowZero {
			return i256.Zero()
		}
	case 1:
		return i256.One()
	case 2:
		return i256.MustFromDecimal(MAX_INT128)
	case 3:
		val := i256.MustFromDecimal(MAX_INT128)
		return new(i256.Int).Add(val, i256.One())
	case 4:
		if g.allowNegative {
			val := i256.MustFromDecimal(MAX_INT128)
			return i256.Zero().Neg(val)
		}
	}

	bits := g.seedMgr.CreateIntGenerator(1, int(g.maxBits)).Generate().(int)
	uval := u256.One()
	uval = new(u256.Uint).Lsh(uval, uint(bits))

	val := i256.FromUint256(uval)

	// Randomly make negative
	if g.allowNegative && g.seedMgr.CreateBoolGenerator().Generate().(bool) {
		val = i256.Zero().Neg(val)
	}

	return val
}

// FuzzWithConfig runs property-based testing with the specified configuration.
// Note: config.Seed is ignored as entropy-based seeding is used.
func FuzzWithConfig(config Config, property func(int) bool) *Result {
	// Note: config.Seed is ignored as we use entropy-based seeding
	return FuzzWithConfigAndGen(config, &IntGenerator{rng: nil}, property)
}

// FuzzWithConfigAndGen runs property-based testing with a custom generator and configuration.
// Returns a Result containing test outcome, failing input (if any), and iteration count.
func FuzzWithConfigAndGen(config Config, gen Generator, property func(int) bool) *Result {
	result := &Result{}
	iterations := config.Iterations
	if iterations == 0 {
		iterations = 100
	}
	var failingInput int
	for i := 0; i < iterations; i++ {
		result.Iterations++
		value := gen.Generate().(int)
		if !property(value) {
			failingInput = value
			result.Failed = true
			break
		}
	}
	if !result.Failed {
		return result
	}
	if config.Shrink {
		result.FailingInput = shrinkInt(property, failingInput)
	} else {
		result.FailingInput = failingInput
	}
	return result
}

// Fuzz runs property-based testing on the given property function.
// Supports func(int) bool and func(string) bool property types. Returns error on property violation.
func Fuzz(property interface{}) error {
	if fn, ok := property.(func(int) bool); ok {
		return FuzzWithGen(IntRange(0, 1000), fn)
	}
	if fn, ok := property.(func(string) bool); ok {
		return fuzzString(fn)
	}
	return errors.New("unsupported property type")
}

// fuzzString runs property-based testing for string properties with 100 iterations.
func fuzzString(fn func(string) bool) error {
	gen := &StringGenerator{rng: nil} // Will be initialized on first use
	for i := 0; i < 100; i++ {
		if !fn(gen.Generate().(string)) {
			return errors.New("property violation")
		}
	}
	return nil
}

// FuzzWithGen runs property-based testing using a custom generator with 100 iterations.
func FuzzWithGen(gen Generator, property func(int) bool) error {
	for i := 0; i < 100; i++ {
		value := gen.Generate().(int)
		if !property(value) {
			return errors.New("property violation")
		}
	}
	return nil
}

// FuzzN runs property-based testing with multiple parameters.
// Currently supports func(int, int) bool property type with 100 iterations per test.
func FuzzN(property interface{}) error {
	if fn, ok := property.(func(int, int) bool); ok {
		gen := &IntGenerator{rng: nil} // Will be initialized on first use
		for i := 0; i < 100; i++ {
			a := gen.Generate().(int)
			b := gen.Generate().(int)
			if !fn(a, b) {
				return errors.New("property violation")
			}
		}
		return nil
	}
	return errors.New("unsupported property type")
}
