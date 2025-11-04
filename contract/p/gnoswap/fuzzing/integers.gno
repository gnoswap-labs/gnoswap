package fuzzing

import "math"

// Integer generators and methods.
// Provides generators for all integer types (int, int8-64, uint, uint8-64).
// Supports full range, min-bounded, max-bounded, and range-bounded variants.

// Generator constructors - Int variants

func Int() *Generator { return newGenerator(&intGen{}) }
func IntMin(min int) *Generator { return newGenerator(&intGen{min: int64(min), hasMin: true}) }
func IntMax(max int) *Generator { return newGenerator(&intGen{max: int64(max), hasMax: true}) }
func IntRange(min, max int) *Generator { return newGenerator(&intGen{min: int64(min), max: int64(max), hasMin: true, hasMax: true}) }

func Int8() *Generator { return newGenerator(&int8Gen{min: math.MinInt8, max: math.MaxInt8}) }
func Int8Min(min int8) *Generator { return newGenerator(&int8Gen{min: int64(min), max: math.MaxInt8}) }
func Int8Max(max int8) *Generator { return newGenerator(&int8Gen{min: math.MinInt8, max: int64(max)}) }
func Int8Range(min, max int8) *Generator { return newGenerator(&int8Gen{min: int64(min), max: int64(max)}) }

func Int16() *Generator { return newGenerator(&int16Gen{min: math.MinInt16, max: math.MaxInt16}) }
func Int16Min(min int16) *Generator { return newGenerator(&int16Gen{min: int64(min), max: math.MaxInt16}) }
func Int16Max(max int16) *Generator { return newGenerator(&int16Gen{min: math.MinInt16, max: int64(max)}) }
func Int16Range(min, max int16) *Generator { return newGenerator(&int16Gen{min: int64(min), max: int64(max)}) }

func Int32() *Generator { return newGenerator(&int32Gen{min: math.MinInt32, max: math.MaxInt32}) }
func Int32Min(min int32) *Generator { return newGenerator(&int32Gen{min: int64(min), max: math.MaxInt32}) }
func Int32Max(max int32) *Generator { return newGenerator(&int32Gen{min: math.MinInt32, max: int64(max)}) }
func Int32Range(min, max int32) *Generator { return newGenerator(&int32Gen{min: int64(min), max: int64(max)}) }

func Int64() *Generator { return newGenerator(&int64Gen{}) }
func Int64Min(min int64) *Generator { return newGenerator(&int64Gen{min: min, hasMin: true}) }
func Int64Max(max int64) *Generator { return newGenerator(&int64Gen{max: max, hasMax: true}) }
func Int64Range(min, max int64) *Generator { return newGenerator(&int64Gen{min: min, max: max, hasMin: true, hasMax: true}) }

// Generator constructors - Uint variants

func Uint() *Generator { return newGenerator(&uintGen{}) }
func UintMin(min uint) *Generator { return newGenerator(&uintGen{min: uint64(min), hasMin: true}) }
func UintMax(max uint) *Generator { return newGenerator(&uintGen{max: uint64(max), hasMax: true}) }
func UintRange(min, max uint) *Generator { return newGenerator(&uintGen{min: uint64(min), max: uint64(max), hasMin: true, hasMax: true}) }

func Uint8() *Generator { return newGenerator(&uint8Gen{max: math.MaxUint8}) }
func Uint8Min(min uint8) *Generator { return newGenerator(&uint8Gen{min: uint64(min), max: math.MaxUint8}) }
func Uint8Max(max uint8) *Generator { return newGenerator(&uint8Gen{max: uint64(max)}) }
func Uint8Range(min, max uint8) *Generator { return newGenerator(&uint8Gen{min: uint64(min), max: uint64(max)}) }

func Uint16() *Generator { return newGenerator(&uint16Gen{max: math.MaxUint16}) }
func Uint16Min(min uint16) *Generator { return newGenerator(&uint16Gen{min: uint64(min), max: math.MaxUint16}) }
func Uint16Max(max uint16) *Generator { return newGenerator(&uint16Gen{max: uint64(max)}) }
func Uint16Range(min, max uint16) *Generator { return newGenerator(&uint16Gen{min: uint64(min), max: uint64(max)}) }

func Uint32() *Generator { return newGenerator(&uint32Gen{max: math.MaxUint32}) }
func Uint32Min(min uint32) *Generator { return newGenerator(&uint32Gen{min: uint64(min), max: math.MaxUint32}) }
func Uint32Max(max uint32) *Generator { return newGenerator(&uint32Gen{max: uint64(max)}) }
func Uint32Range(min, max uint32) *Generator { return newGenerator(&uint32Gen{min: uint64(min), max: uint64(max)}) }

func Uint64() *Generator { return newGenerator(&uint64Gen{}) }
func Uint64Min(min uint64) *Generator { return newGenerator(&uint64Gen{min: min, hasMin: true}) }
func Uint64Max(max uint64) *Generator { return newGenerator(&uint64Gen{max: max, hasMax: true}) }
func Uint64Range(min, max uint64) *Generator { return newGenerator(&uint64Gen{min: min, max: max, hasMin: true, hasMax: true}) }

// T convenience methods - Int variants

func (t *T) Int() int { return Int().value(t).(int) }
func (t *T) IntMin(min int) int { return IntMin(min).value(t).(int) }
func (t *T) IntMax(max int) int { return IntMax(max).value(t).(int) }
func (t *T) IntRange(min, max int) int { return IntRange(min, max).value(t).(int) }

func (t *T) Int8() int8 { return Int8().value(t).(int8) }
func (t *T) Int8Min(min int8) int8 { return Int8Min(min).value(t).(int8) }
func (t *T) Int8Max(max int8) int8 { return Int8Max(max).value(t).(int8) }
func (t *T) Int8Range(min, max int8) int8 { return Int8Range(min, max).value(t).(int8) }

func (t *T) Int16() int16 { return Int16().value(t).(int16) }
func (t *T) Int16Min(min int16) int16 { return Int16Min(min).value(t).(int16) }
func (t *T) Int16Max(max int16) int16 { return Int16Max(max).value(t).(int16) }
func (t *T) Int16Range(min, max int16) int16 { return Int16Range(min, max).value(t).(int16) }

func (t *T) Int32() int32 { return Int32().value(t).(int32) }
func (t *T) Int32Min(min int32) int32 { return Int32Min(min).value(t).(int32) }
func (t *T) Int32Max(max int32) int32 { return Int32Max(max).value(t).(int32) }
func (t *T) Int32Range(min, max int32) int32 { return Int32Range(min, max).value(t).(int32) }

func (t *T) Int64() int64 { return Int64().value(t).(int64) }
func (t *T) Int64Min(min int64) int64 { return Int64Min(min).value(t).(int64) }
func (t *T) Int64Max(max int64) int64 { return Int64Max(max).value(t).(int64) }
func (t *T) Int64Range(min, max int64) int64 { return Int64Range(min, max).value(t).(int64) }

// T convenience methods - Uint variants

func (t *T) Uint() uint { return Uint().value(t).(uint) }
func (t *T) UintMin(min uint) uint { return UintMin(min).value(t).(uint) }
func (t *T) UintMax(max uint) uint { return UintMax(max).value(t).(uint) }
func (t *T) UintRange(min, max uint) uint { return UintRange(min, max).value(t).(uint) }

func (t *T) Uint8() uint8 { return Uint8().value(t).(uint8) }
func (t *T) Uint8Min(min uint8) uint8 { return Uint8Min(min).value(t).(uint8) }
func (t *T) Uint8Max(max uint8) uint8 { return Uint8Max(max).value(t).(uint8) }
func (t *T) Uint8Range(min, max uint8) uint8 { return Uint8Range(min, max).value(t).(uint8) }

func (t *T) Uint16() uint16 { return Uint16().value(t).(uint16) }
func (t *T) Uint16Min(min uint16) uint16 { return Uint16Min(min).value(t).(uint16) }
func (t *T) Uint16Max(max uint16) uint16 { return Uint16Max(max).value(t).(uint16) }
func (t *T) Uint16Range(min, max uint16) uint16 { return Uint16Range(min, max).value(t).(uint16) }

func (t *T) Uint32() uint32 { return Uint32().value(t).(uint32) }
func (t *T) Uint32Min(min uint32) uint32 { return Uint32Min(min).value(t).(uint32) }
func (t *T) Uint32Max(max uint32) uint32 { return Uint32Max(max).value(t).(uint32) }
func (t *T) Uint32Range(min, max uint32) uint32 { return Uint32Range(min, max).value(t).(uint32) }

func (t *T) Uint64() uint64 { return Uint64().value(t).(uint64) }
func (t *T) Uint64Min(min uint64) uint64 { return Uint64Min(min).value(t).(uint64) }
func (t *T) Uint64Max(max uint64) uint64 { return Uint64Max(max).value(t).(uint64) }
func (t *T) Uint64Range(min, max uint64) uint64 { return Uint64Range(min, max).value(t).(uint64) }

// String methods

func (g *intGen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("IntRange(%d, %d)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("IntMin(%d)", g.min)
	} else if g.hasMax {
		return sprintf("IntMax(%d)", g.max)
	}
	return "Int()"
}

func (g *int8Gen) String() string {
	if g.min == math.MinInt8 && g.max == math.MaxInt8 {
		return "Int8()"
	} else if g.min == math.MinInt8 {
		return sprintf("Int8Max(%d)", g.max)
	} else if g.max == math.MaxInt8 {
		return sprintf("Int8Min(%d)", g.min)
	}
	return sprintf("Int8Range(%d, %d)", g.min, g.max)
}

func (g *int16Gen) String() string {
	if g.min == math.MinInt16 && g.max == math.MaxInt16 {
		return "Int16()"
	} else if g.min == math.MinInt16 {
		return sprintf("Int16Max(%d)", g.max)
	} else if g.max == math.MaxInt16 {
		return sprintf("Int16Min(%d)", g.min)
	}
	return sprintf("Int16Range(%d, %d)", g.min, g.max)
}

func (g *int32Gen) String() string {
	if g.min == math.MinInt32 && g.max == math.MaxInt32 {
		return "Int32()"
	} else if g.min == math.MinInt32 {
		return sprintf("Int32Max(%d)", g.max)
	} else if g.max == math.MaxInt32 {
		return sprintf("Int32Min(%d)", g.min)
	}
	return sprintf("Int32Range(%d, %d)", g.min, g.max)
}

func (g *int64Gen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("Int64Range(%d, %d)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("Int64Min(%d)", g.min)
	} else if g.hasMax {
		return sprintf("Int64Max(%d)", g.max)
	}
	return "Int64()"
}

func (g *uintGen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("UintRange(%d, %d)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("UintMin(%d)", g.min)
	} else if g.hasMax {
		return sprintf("UintMax(%d)", g.max)
	}
	return "Uint()"
}

func (g *uint8Gen) String() string {
	if g.min == 0 && g.max == math.MaxUint8 {
		return "Uint8()"
	} else if g.min == 0 {
		return sprintf("Uint8Max(%d)", g.max)
	} else if g.max == math.MaxUint8 {
		return sprintf("Uint8Min(%d)", g.min)
	}
	return sprintf("Uint8Range(%d, %d)", g.min, g.max)
}

func (g *uint16Gen) String() string {
	if g.min == 0 && g.max == math.MaxUint16 {
		return "Uint16()"
	} else if g.min == 0 {
		return sprintf("Uint16Max(%d)", g.max)
	} else if g.max == math.MaxUint16 {
		return sprintf("Uint16Min(%d)", g.min)
	}
	return sprintf("Uint16Range(%d, %d)", g.min, g.max)
}

func (g *uint32Gen) String() string {
	if g.min == 0 && g.max == math.MaxUint32 {
		return "Uint32()"
	} else if g.min == 0 {
		return sprintf("Uint32Max(%d)", g.max)
	} else if g.max == math.MaxUint32 {
		return sprintf("Uint32Min(%d)", g.min)
	}
	return sprintf("Uint32Range(%d, %d)", g.min, g.max)
}

func (g *uint64Gen) String() string {
	if g.hasMin && g.hasMax {
		return sprintf("Uint64Range(%d, %d)", g.min, g.max)
	} else if g.hasMin {
		return sprintf("Uint64Min(%d)", g.min)
	} else if g.hasMax {
		return sprintf("Uint64Max(%d)", g.max)
	}
	return "Uint64()"
}

// value methods

func (g *intGen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = math.MinInt64
	}
	if !g.hasMax {
		max = math.MaxInt64
	}
	v, _, _ := genIntRange(t.s, min, max, true)
	return int(v)
}

func (g *int8Gen) value(t *T) any {
	v, _, _ := genIntRange(t.s, g.min, g.max, true)
	return int8(v)
}

func (g *int16Gen) value(t *T) any {
	v, _, _ := genIntRange(t.s, g.min, g.max, true)
	return int16(v)
}

func (g *int32Gen) value(t *T) any {
	v, _, _ := genIntRange(t.s, g.min, g.max, true)
	return int32(v)
}

func (g *int64Gen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = math.MinInt64
	}
	if !g.hasMax {
		max = math.MaxInt64
	}
	v, _, _ := genIntRange(t.s, min, max, true)
	return v
}

func (g *uintGen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = 0
	}
	if !g.hasMax {
		max = math.MaxUint64
	}
	v, _, _ := genUintRange(t.s, min, max, true)
	return uint(v)
}

func (g *uint8Gen) value(t *T) any {
	v, _, _ := genUintRange(t.s, g.min, g.max, true)
	return uint8(v)
}

func (g *uint16Gen) value(t *T) any {
	v, _, _ := genUintRange(t.s, g.min, g.max, true)
	return uint16(v)
}

func (g *uint32Gen) value(t *T) any {
	v, _, _ := genUintRange(t.s, g.min, g.max, true)
	return uint32(v)
}

func (g *uint64Gen) value(t *T) any {
	min, max := g.min, g.max
	if !g.hasMin {
		min = 0
	}
	if !g.hasMax {
		max = math.MaxUint64
	}
	v, _, _ := genUintRange(t.s, min, max, true)
	return v
}

// Type definitions

type intGen struct {
	min    int64
	max    int64
	hasMin bool
	hasMax bool
}

type int8Gen struct {
	min int64
	max int64
}

type int16Gen struct {
	min int64
	max int64
}

type int32Gen struct {
	min int64
	max int64
}

type int64Gen struct {
	min    int64
	max    int64
	hasMin bool
	hasMax bool
}

type uintGen struct {
	min    uint64
	max    uint64
	hasMin bool
	hasMax bool
}

type uint8Gen struct {
	min uint64
	max uint64
}

type uint16Gen struct {
	min uint64
	max uint64
}

type uint32Gen struct {
	min uint64
	max uint64
}

type uint64Gen struct {
	min    uint64
	max    uint64
	hasMin bool
	hasMax bool
}
