package fuzzing

import "math"

// Float generators and methods.
// Provides generators for float32 and float64 types.
// Supports full range, min-bounded, max-bounded, and range-bounded variants.

// Generator constructors

func Float64() *Generator { return newGenerator(&float64Gen{}) }
func Float64Min(min float64) *Generator { return newGenerator(&float64Gen{min: min, hasMin: true}) }
func Float64Max(max float64) *Generator { return newGenerator(&float64Gen{max: max, hasMax: true}) }
func Float64Range(min, max float64) *Generator { return newGenerator(&float64Gen{min: min, max: max, hasMin: true, hasMax: true}) }

func Float32() *Generator { return newGenerator(&float32Gen{}) }
func Float32Min(min float32) *Generator { return newGenerator(&float32Gen{min: min, hasMin: true}) }
func Float32Max(max float32) *Generator { return newGenerator(&float32Gen{max: max, hasMax: true}) }
func Float32Range(min, max float32) *Generator { return newGenerator(&float32Gen{min: min, max: max, hasMin: true, hasMax: true}) }

// T convenience methods

func (t *T) Float64() float64 { return Float64().value(t).(float64) }
func (t *T) Float64Min(min float64) float64 { return Float64Min(min).value(t).(float64) }
func (t *T) Float64Max(max float64) float64 { return Float64Max(max).value(t).(float64) }
func (t *T) Float64Range(min, max float64) float64 { return Float64Range(min, max).value(t).(float64) }

func (t *T) Float32() float32 { return Float32().value(t).(float32) }
func (t *T) Float32Min(min float32) float32 { return Float32Min(min).value(t).(float32) }
func (t *T) Float32Max(max float32) float32 { return Float32Max(max).value(t).(float32) }
func (t *T) Float32Range(min, max float32) float32 { return Float32Range(min, max).value(t).(float32) }

// String methods

func (g *float64Gen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("Float64Range(%g, %g)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("Float64Min(%g)", g.min)
	} else if g.hasMax {
		return sprintf("Float64Max(%g)", g.max)
	}
	return "Float64()"
}

func (g *float32Gen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("Float32Range(%g, %g)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("Float32Min(%g)", g.min)
	} else if g.hasMax {
		return sprintf("Float32Max(%g)", g.max)
	}
	return "Float32()"
}

// value methods

func (g *float64Gen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = -math.MaxFloat64
	}
	if !g.hasMax {
		max = math.MaxFloat64
	}
	return genFloat64Range(t.s, min, max, true)
}

func (g *float32Gen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = -math.MaxFloat32
	}
	if !g.hasMax {
		max = math.MaxFloat32
	}
	return genFloat32Range(t.s, min, max, true)
}

// Type definitions

type float64Gen struct {
	min    float64
	max    float64
	hasMin bool
	hasMax bool
}

type float32Gen struct {
	min    float32
	max    float32
	hasMin bool
	hasMax bool
}
