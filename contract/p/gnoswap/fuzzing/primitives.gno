package fuzzing

// Primitive type generators and methods.
// Provides generators for bool and byte types.

// Type definitions

type boolGen struct{}

type byteGen struct{}

type byteRangeGen struct {
	min byte
	max byte
}

// String methods

func (g *boolGen) String() string {
	return "Bool()"
}

func (g *byteGen) String() string {
	return "Byte()"
}

func (g *byteRangeGen) String() string {
	return sprintf("ByteRange(%d, %d)", g.min, g.max)
}

// value methods

func (g *boolGen) value(t *T) any {
	return flipBiasedCoin(t.s, 0.5)
}

func (g *byteGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, 0, 255, true)
	return byte(v)
}

func (g *byteRangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return byte(v)
}

// Generator constructors

// Bool creates a boolean generator.
func Bool() *Generator {
	return newGenerator(&boolGen{})
}

// Byte creates a byte generator.
func Byte() *Generator {
	return newGenerator(&byteGen{})
}

// ByteRange creates a generator for bytes in [min, max].
func ByteRange(min, max byte) *Generator {
	return newGenerator(&byteRangeGen{min: min, max: max})
}

// T convenience methods

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
