package fuzzing

// Float generators and methods.
// Provides generators for float32 and float64 types.

// Type definitions

type float64RangeGen struct {
	min float64
	max float64
}

type float32RangeGen struct {
	min float32
	max float32
}

// String methods

func (g *float64RangeGen) String() string {
	return "Float64Range(...)"
}

func (g *float32RangeGen) String() string {
	return "Float32Range(...)"
}

// value methods

func (g *float64RangeGen) value(t *T) any {
	return genFloat64Range(t.s, g.min, g.max, true)
}

func (g *float32RangeGen) value(t *T) any {
	return genFloat32Range(t.s, g.min, g.max, true)
}

// Generator constructors

// Float64Range creates a generator for float64 in [min, max].
func Float64Range(min, max float64) *Generator {
	return newGenerator(&float64RangeGen{min: min, max: max})
}

// Float32Range creates a generator for float32 in [min, max].
func Float32Range(min, max float32) *Generator {
	return newGenerator(&float32RangeGen{min: min, max: max})
}

// T convenience methods

// Float64Range generates a float64 in [min, max].
func (t *T) Float64Range(min, max float64) float64 {
	return Float64Range(min, max).value(t).(float64)
}

// Float32Range generates a float32 in [min, max].
func (t *T) Float32Range(min, max float32) float32 {
	return Float32Range(min, max).value(t).(float32)
}
