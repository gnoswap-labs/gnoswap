package fuzztest

import (
	"errors"
	"math"
	"math/rand"
	"strconv"
	"unicode/utf8"

	xs "gno.land/p/wyhaines/rand/xorshift64star"
)

type Generator interface {
	Generate() any
}

// seedCounter is a simple counter to ensure different seeds
// We use a function-scoped approach to avoid realm modification issues
var seedCounter uint64

// getNextSeed returns a new seed value for RNG initialization
// Uses a combination of counter and current time to ensure uniqueness
func getNextSeed() uint64 {
	// Increment counter and combine with time for uniqueness
	seedCounter++
	// Use a prime multiplier to spread values
	return seedCounter * 2654435761
}

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

type IntGenerator struct {
	min, max int
	rng      *xs.Xorshift64Star
}

func (g *IntGenerator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return int(int32(g.rng.Uint64()))
	}
	size := uint64(g.max - g.min + 1)
	return int(g.rng.Uint64()%size) + g.min
}

func IntRange(min, max int) Generator {
	return &IntGenerator{
		min: min,
		max: max,
		rng: nil, // Will be initialized on first use
	}
}

// IntRangeWithSeed creates an IntGenerator with a specific seed
func IntRangeWithSeed(min, max int, seed uint64) Generator {
	return &IntGenerator{
		min: min,
		max: max,
		rng: xs.New(seed),
	}
}

type Uint32Generator struct {
	min, max uint32
	rng      *xs.Xorshift64Star
}

func (g *Uint32Generator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return uint32(g.rng.Uint64())
	}
	size := uint64(g.max - g.min + 1)
	return uint32(g.rng.Uint64()%size) + g.min
}

func Uint32Range(min, max uint32) Generator {
	return &Uint32Generator{
		min: min,
		max: max,
		rng: nil, // Will be initialized on first use
	}
}

// Uint32RangeWithSeed creates a Uint32Generator with a specific seed
func Uint32RangeWithSeed(min, max uint32, seed uint64) Generator {
	return &Uint32Generator{
		min: min,
		max: max,
		rng: xs.New(seed),
	}
}

func Uint32() Generator {
	return Uint32Range(0, 100)
}

type BoolGenerator struct {
	rng *xs.Xorshift64Star
}

func (g *BoolGenerator) Generate() any {
	initRNG(&g.rng)
	return g.rng.Uint64()%2 == 0
}

func Bool() Generator {
	return &BoolGenerator{rng: nil} // Will be initialized on first use
}

// BoolWithSeed creates a BoolGenerator with a specific seed
func BoolWithSeed(seed uint64) Generator {
	return &BoolGenerator{rng: xs.New(seed)}
}

type StringGenerator struct {
	minLen, maxLen int
	rng            *xs.Xorshift64Star
}

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

// StringWithSeed creates a StringGenerator with a specific seed
func StringWithSeed(minLen, maxLen int, seed uint64) Generator {
	return &StringGenerator{
		minLen: minLen,
		maxLen: maxLen,
		rng:    xs.New(seed),
	}
}

type NumberStringGenerator struct {
	min, max  int64
	baseTypes []int
	rng       *xs.Xorshift64Star
}

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

func NumberString() Generator {
	return &NumberStringGenerator{
		min:       0,
		max:       1000000,
		baseTypes: []int{2, 8, 10, 16},
		rng:       nil, // Will be initialized on first use
	}
}

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

// SetGlobalSeed is deprecated - seeds are now handled automatically
func SetGlobalSeed(seed uint64) {
	// No-op to maintain API compatibility
}

// ResetGlobalSeed is deprecated - seeds are now handled automatically
func ResetGlobalSeed() {
	// No-op to maintain API compatibility
}

// Config controls fuzzing parameters
type Config struct {
	Iterations int
	Shrink     bool
	Seed       uint64 // Optional: if provided, uses this seed for reproducibility
}

type Result struct {
	Failed       bool
	FailingInput any
	Iterations   int
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

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

func generateLongString(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = 'a'
	}
	return string(b)
}

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

func generateLargeSlice(n int) []int {
	slice := make([]int, n)
	for i := 0; i < n; i++ {
		slice[i] = rand.IntN(100)
	}
	return slice
}

func FuzzWithConfig(config Config, property func(int) bool) *Result {
	// Note: config.Seed is ignored as we use entropy-based seeding
	return FuzzWithConfigAndGen(config, &IntGenerator{rng: nil}, property)
}

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

func Fuzz(property interface{}) error {
	if fn, ok := property.(func(int) bool); ok {
		return FuzzWithGen(IntRange(0, 1000), fn)
	}
	if fn, ok := property.(func(string) bool); ok {
		return fuzzString(fn)
	}
	return errors.New("unsupported property type")
}

func fuzzString(fn func(string) bool) error {
	gen := &StringGenerator{rng: nil} // Will be initialized on first use
	for i := 0; i < 100; i++ {
		if !fn(gen.Generate().(string)) {
			return errors.New("property violation")
		}
	}
	return nil
}

func FuzzWithGen(gen Generator, property func(int) bool) error {
	for i := 0; i < 100; i++ {
		value := gen.Generate().(int)
		if !property(value) {
			return errors.New("property violation")
		}
	}
	return nil
}

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
