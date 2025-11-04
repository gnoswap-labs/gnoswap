package fuzzing

import "math"

// String and rune generators and methods.
// Provides generators for strings and runes with various configurations.

// Generator constructors

func Rune() *Generator { return newGenerator(&runeGen{}) }
func RuneRange(min, max rune) *Generator { return newGenerator(&runeRangeGen{min: min, max: max}) }

func String() *Generator { return newGenerator(&stringGen{minLen: 0, maxLen: 100}) }
func StringN(minLen, maxLen int) *Generator { return newGenerator(&stringGen{minLen: minLen, maxLen: maxLen}) }

func StringOf(runeGen *Generator) *Generator { return newGenerator(&stringOfGen{runeGen: runeGen, minLen: 0, maxLen: 100}) }
func StringOfN(runeGen *Generator, minLen, maxLen int) *Generator { return newGenerator(&stringOfGen{runeGen: runeGen, minLen: minLen, maxLen: maxLen}) }

// T convenience methods

func (t *T) Rune() rune { return Rune().value(t).(rune) }
func (t *T) RuneRange(min, max rune) rune { return RuneRange(min, max).value(t).(rune) }

func (t *T) String() string { return String().value(t).(string) }
func (t *T) StringN(minLen, maxLen int) string { return StringN(minLen, maxLen).value(t).(string) }

func (t *T) StringOf(runeGen *Generator) string { return StringOf(runeGen).value(t).(string) }
func (t *T) StringOfN(runeGen *Generator, minLen, maxLen int) string { return StringOfN(runeGen, minLen, maxLen).value(t).(string) }

// String methods

func (g *runeGen) String() string { return "Rune()" }
func (g *runeRangeGen) String() string { return sprintf("RuneRange(%d, %d)", g.min, g.max) }

func (g *stringGen) String() string {
	if g.minLen == 0 && g.maxLen == math.MaxInt {
		return "String()"
	}
	return "StringN(...)"
}

func (g *stringOfGen) String() string { return "StringOf(" + g.runeGen.String() + ")" }

// value methods

func (g *runeGen) value(t *T) any {
	// Generate valid Unicode code points
	v, _, _ := genIntRange(t.s, 0, 0x10FFFF, true)
	// Skip surrogate pairs (0xD800-0xDFFF)
	if v >= 0xD800 && v <= 0xDFFF {
		v = 0x20 // Default to space
	}
	return rune(v)
}

func (g *runeRangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return rune(v)
}

func (g *stringGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	runes := make([]rune, n)
	for i := range runes {
		runes[i] = Rune().value(t).(rune)
	}
	return string(runes)
}

func (g *stringOfGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	runes := make([]rune, n)
	for i := range runes {
		runes[i] = g.runeGen.value(t).(rune)
	}
	return string(runes)
}

// Type definitions

type runeGen struct{}

type runeRangeGen struct {
	min rune
	max rune
}

type stringGen struct {
	minLen int
	maxLen int
}

type stringOfGen struct {
	runeGen *Generator
	minLen  int
	maxLen  int
}
