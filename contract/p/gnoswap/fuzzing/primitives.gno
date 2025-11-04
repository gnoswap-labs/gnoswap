package fuzzing

import "math"

// Primitive type generators: Int, Bool, Byte, Rune, String

// intRangeGen generates integers in a range.
type intRangeGen struct {
	min int
	max int
}

func (g *intRangeGen) String() string {
	return "IntRange(...)"
}

func (g *intRangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int(v)
}

// IntRange creates a generator for integers in [min, max].
func IntRange(min, max int) *Generator {
	return newGenerator(&intRangeGen{min: min, max: max})
}

// int64RangeGen generates int64 in a range.
type int64RangeGen struct {
	min int64
	max int64
}

func (g *int64RangeGen) String() string {
	return "Int64Range(...)"
}

func (g *int64RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, g.min, g.max, true)
	return v
}

// Int64Range creates a generator for int64 in [min, max].
func Int64Range(min, max int64) *Generator {
	return newGenerator(&int64RangeGen{min: min, max: max})
}

// uintRangeGen generates uints in a range.
type uintRangeGen struct {
	min uint
	max uint
}

func (g *uintRangeGen) String() string {
	return "UintRange(...)"
}

func (g *uintRangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint(v)
}

// UintRange creates a generator for uints in [min, max].
func UintRange(min, max uint) *Generator {
	return newGenerator(&uintRangeGen{min: min, max: max})
}

// uint64RangeGen generates uint64 in a range.
type uint64RangeGen struct {
	min uint64
	max uint64
}

func (g *uint64RangeGen) String() string {
	return "Uint64Range(...)"
}

func (g *uint64RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, g.min, g.max, true)
	return v
}

// Uint64Range creates a generator for uint64 in [min, max].
func Uint64Range(min, max uint64) *Generator {
	return newGenerator(&uint64RangeGen{min: min, max: max})
}

// boolGen generates booleans.
type boolGen struct{}

func (g *boolGen) String() string {
	return "Bool()"
}

func (g *boolGen) value(t *T) any {
	return flipBiasedCoin(t.s, 0.5)
}

// Bool creates a boolean generator.
func Bool() *Generator {
	return newGenerator(&boolGen{})
}

// byteGen generates bytes.
type byteGen struct{}

func (g *byteGen) String() string {
	return "Byte()"
}

func (g *byteGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, 0, 255, true)
	return byte(v)
}

// Byte creates a byte generator.
func Byte() *Generator {
	return newGenerator(&byteGen{})
}

// byteRangeGen generates bytes in a range.
type byteRangeGen struct {
	min byte
	max byte
}

func (g *byteRangeGen) String() string {
	return "ByteRange(...)"
}

func (g *byteRangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return byte(v)
}

// ByteRange creates a generator for bytes in [min, max].
func ByteRange(min, max byte) *Generator {
	return newGenerator(&byteRangeGen{min: min, max: max})
}

// runeGen generates runes.
type runeGen struct{}

func (g *runeGen) String() string {
	return "Rune()"
}

func (g *runeGen) value(t *T) any {
	// Generate valid Unicode code points
	v, _, _ := genIntRange(t.s, 0, 0x10FFFF, true)
	// Skip surrogate pairs (0xD800-0xDFFF)
	if v >= 0xD800 && v <= 0xDFFF {
		v = 0x20 // Default to space
	}
	return rune(v)
}

// Rune creates a rune generator.
func Rune() *Generator {
	return newGenerator(&runeGen{})
}

// runeRangeGen generates runes in a range.
type runeRangeGen struct {
	min rune
	max rune
}

func (g *runeRangeGen) String() string {
	return "RuneRange(...)"
}

func (g *runeRangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return rune(v)
}

// RuneRange creates a generator for runes in [min, max].
func RuneRange(min, max rune) *Generator {
	return newGenerator(&runeRangeGen{min: min, max: max})
}

// stringGen generates strings.
type stringGen struct {
	minLen int
	maxLen int
}

func (g *stringGen) String() string {
	if g.minLen == 0 && g.maxLen == math.MaxInt {
		return "String()"
	}
	return "StringN(...)"
}

func (g *stringGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	runes := make([]rune, n)
	for i := range runes {
		runes[i] = Rune().value(t).(rune)
	}
	return string(runes)
}

// String creates a string generator.
func String() *Generator {
	return newGenerator(&stringGen{minLen: 0, maxLen: 100})
}

// StringN creates a string generator with length in [minLen, maxLen].
func StringN(minLen, maxLen int) *Generator {
	return newGenerator(&stringGen{minLen: minLen, maxLen: maxLen})
}
