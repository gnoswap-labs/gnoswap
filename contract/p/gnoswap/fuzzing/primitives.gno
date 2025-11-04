package fuzzing

// Primitive type generators and methods.
// Provides generators for bool and byte types.

// Type definitions

type boolGen struct{}

type byteGen struct {
	min    uint64
	max    uint64
	hasMin bool
	hasMax bool
}

// String methods

func (g *boolGen) String() string { return "Bool()" }

func (g *byteGen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("ByteRange(%d, %d)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("ByteMin(%d)", g.min)
	} else if g.hasMax {
		return sprintf("ByteMax(%d)", g.max)
	}
	return "Byte()"
}

// value methods

func (g *boolGen) value(t *T) any { return flipBiasedCoin(t.s, 0.5) }

func (g *byteGen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = 0
	}
	if !g.hasMax {
		max = 255
	}
	v, _, _ := genUintRange(t.s, min, max, true)
	return byte(v)
}

// Generator constructors

func Bool() *Generator { return newGenerator(&boolGen{}) }

func Byte() *Generator { return newGenerator(&byteGen{}) }
func ByteMin(min byte) *Generator { return newGenerator(&byteGen{min: uint64(min), hasMin: true}) }
func ByteMax(max byte) *Generator { return newGenerator(&byteGen{max: uint64(max), hasMax: true}) }
func ByteRange(min, max byte) *Generator { return newGenerator(&byteGen{min: uint64(min), max: uint64(max), hasMin: true, hasMax: true}) }

// T convenience methods

func (t *T) Bool() bool { return Bool().value(t).(bool) }

func (t *T) Byte() byte { return Byte().value(t).(byte) }
func (t *T) ByteMin(min byte) byte { return ByteMin(min).value(t).(byte) }
func (t *T) ByteMax(max byte) byte { return ByteMax(max).value(t).(byte) }
func (t *T) ByteRange(min, max byte) byte { return ByteRange(min, max).value(t).(byte) }
