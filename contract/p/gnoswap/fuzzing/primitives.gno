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

// int32RangeGen generates int32 in a range.
type int32RangeGen struct {
	min int32
	max int32
}

func (g *int32RangeGen) String() string {
	return "Int32Range(...)"
}

func (g *int32RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int32(v)
}

// Int32Range creates a generator for int32 in [min, max].
func Int32Range(min, max int32) *Generator {
	return newGenerator(&int32RangeGen{min: min, max: max})
}

// int16RangeGen generates int16 in a range.
type int16RangeGen struct {
	min int16
	max int16
}

func (g *int16RangeGen) String() string {
	return "Int16Range(...)"
}

func (g *int16RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int16(v)
}

// Int16Range creates a generator for int16 in [min, max].
func Int16Range(min, max int16) *Generator {
	return newGenerator(&int16RangeGen{min: min, max: max})
}

// int8RangeGen generates int8 in a range.
type int8RangeGen struct {
	min int8
	max int8
}

func (g *int8RangeGen) String() string {
	return "Int8Range(...)"
}

func (g *int8RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int8(v)
}

// Int8Range creates a generator for int8 in [min, max].
func Int8Range(min, max int8) *Generator {
	return newGenerator(&int8RangeGen{min: min, max: max})
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

// uint32RangeGen generates uint32 in a range.
type uint32RangeGen struct {
	min uint32
	max uint32
}

func (g *uint32RangeGen) String() string {
	return "Uint32Range(...)"
}

func (g *uint32RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint32(v)
}

// Uint32Range creates a generator for uint32 in [min, max].
func Uint32Range(min, max uint32) *Generator {
	return newGenerator(&uint32RangeGen{min: min, max: max})
}

// uint16RangeGen generates uint16 in a range.
type uint16RangeGen struct {
	min uint16
	max uint16
}

func (g *uint16RangeGen) String() string {
	return "Uint16Range(...)"
}

func (g *uint16RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint16(v)
}

// Uint16Range creates a generator for uint16 in [min, max].
func Uint16Range(min, max uint16) *Generator {
	return newGenerator(&uint16RangeGen{min: min, max: max})
}

// uint8RangeGen generates uint8 in a range.
type uint8RangeGen struct {
	min uint8
	max uint8
}

func (g *uint8RangeGen) String() string {
	return "Uint8Range(...)"
}

func (g *uint8RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint8(v)
}

// Uint8Range creates a generator for uint8 in [min, max].
func Uint8Range(min, max uint8) *Generator {
	return newGenerator(&uint8RangeGen{min: min, max: max})
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

// float64RangeGen generates float64 in a range.
type float64RangeGen struct {
	min float64
	max float64
}

func (g *float64RangeGen) String() string {
	return "Float64Range(...)"
}

func (g *float64RangeGen) value(t *T) any {
	return genFloat64Range(t.s, g.min, g.max, true)
}

// Float64Range creates a generator for float64 in [min, max].
func Float64Range(min, max float64) *Generator {
	return newGenerator(&float64RangeGen{min: min, max: max})
}

// float32RangeGen generates float32 in a range.
type float32RangeGen struct {
	min float32
	max float32
}

func (g *float32RangeGen) String() string {
	return "Float32Range(...)"
}

func (g *float32RangeGen) value(t *T) any {
	return genFloat32Range(t.s, g.min, g.max, true)
}

// Float32Range creates a generator for float32 in [min, max].
func Float32Range(min, max float32) *Generator {
	return newGenerator(&float32RangeGen{min: min, max: max})
}

// stringOfGen generates strings from custom rune generator.
type stringOfGen struct {
	runeGen *Generator
	minLen  int
	maxLen  int
}

func (g *stringOfGen) String() string {
	return "StringOf(" + g.runeGen.String() + ")"
}

func (g *stringOfGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	runes := make([]rune, n)
	for i := range runes {
		runes[i] = g.runeGen.value(t).(rune)
	}
	return string(runes)
}

// StringOf creates a string generator using custom rune generator.
func StringOf(runeGen *Generator) *Generator {
	return newGenerator(&stringOfGen{runeGen: runeGen, minLen: 0, maxLen: 100})
}

// StringOfN creates a string generator with custom rune generator and length bounds.
func StringOfN(runeGen *Generator, minLen, maxLen int) *Generator {
	return newGenerator(&stringOfGen{runeGen: runeGen, minLen: minLen, maxLen: maxLen})
}
