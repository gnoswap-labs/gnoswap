// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"fmt"
	"math"
)

const (
	intSize    = 64 // Gno uses 64-bit integers
	uintSize   = 64
	maxUintptr = math.MaxUint64
)

// boolGen generates boolean values
type boolGen struct{}

func (g *boolGen) String() string {
	return "Bool()"
}

func (g *boolGen) value(t *T) any {
	return t.s.drawBits(1) == 1
}

// Bool creates a generator for bool values
func Bool() *Generator {
	return newGenerator(&boolGen{})
}

// integerGen generates integer values with optional min/max constraints
type integerGen struct {
	kind    string
	signed  bool
	smin    int64
	smax    int64
	umin    uint64
	umax    uint64
	hasMin  bool
	hasMax  bool
	bitSize int // 8, 16, 32, 64, or 0 for native int/uint
}

func (g *integerGen) String() string {
	if g.hasMin && g.hasMax {
		if g.signed {
			return fmt.Sprintf("%sRange(%d, %d)", g.kind, g.smin, g.smax)
		}
		return fmt.Sprintf("%sRange(%d, %d)", g.kind, g.umin, g.umax)
	} else if g.hasMin {
		if g.signed {
			return fmt.Sprintf("%sMin(%d)", g.kind, g.smin)
		}
		return fmt.Sprintf("%sMin(%d)", g.kind, g.umin)
	} else if g.hasMax {
		if g.signed {
			return fmt.Sprintf("%sMax(%d)", g.kind, g.smax)
		}
		return fmt.Sprintf("%sMax(%d)", g.kind, g.umax)
	}
	return fmt.Sprintf("%s()", g.kind)
}

func (g *integerGen) value(t *T) any {
	if g.signed {
		i, _, _ := genIntRange(t.s, g.smin, g.smax, true)
		switch g.bitSize {
		case 8:
			return int8(i)
		case 16:
			return int16(i)
		case 32:
			return int32(i)
		case 64:
			return i
		default: // native int
			return int(i)
		}
	}
	u, _, _ := genUintRange(t.s, g.umin, g.umax, true)
	switch g.bitSize {
	case 8:
		return uint8(u)
	case 16:
		return uint16(u)
	case 32:
		return uint32(u)
	case 64:
		return u
	default: // native uint
		return uint(u)
	}
}

// Int8 creates a generator for int8 values
func Int8() *Generator {
	return newGenerator(&integerGen{
		kind:    "Int8",
		signed:  true,
		smin:    math.MinInt8,
		smax:    math.MaxInt8,
		bitSize: 8,
	})
}

// Int8Min creates a generator for int8 values >= min
func Int8Min(min int8) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int8",
		signed:  true,
		bitSize: 8,
		smin:    int64(min),
		smax:    math.MaxInt8,
		hasMin:  true,
	})
}

// Int8Max creates a generator for int8 values <= max
func Int8Max(max int8) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int8",
		signed:  true,
		bitSize: 8,
		smin:    math.MinInt8,
		smax:    int64(max),
		hasMax:  true,
	})
}

// Int8Range creates a generator for int8 values in [min, max]
func Int8Range(min int8, max int8) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Int8",
		signed:  true,
		bitSize: 8,
		smin:    int64(min),
		smax:    int64(max),
		hasMin:  true,
		hasMax:  true,
	})
}

// Int16 creates a generator for int16 values
func Int16() *Generator {
	return newGenerator(&integerGen{
		kind:    "Int16",
		signed:  true,
		bitSize: 16,
		smin:    math.MinInt16,
		smax:    math.MaxInt16,
	})
}

// Int16Min creates a generator for int16 values >= min
func Int16Min(min int16) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int16",
		signed:  true,
		bitSize: 16,
		smin:    int64(min),
		smax:    math.MaxInt16,
		hasMin:  true,
	})
}

// Int16Max creates a generator for int16 values <= max
func Int16Max(max int16) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int16",
		signed:  true,
		bitSize: 16,
		smin:    math.MinInt16,
		smax:    int64(max),
		hasMax:  true,
	})
}

// Int16Range creates a generator for int16 values in [min, max]
func Int16Range(min int16, max int16) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Int16",
		signed:  true,
		bitSize: 16,
		smin:    int64(min),
		smax:    int64(max),
		hasMin:  true,
		hasMax:  true,
	})
}

// Int32 creates a generator for int32 values
func Int32() *Generator {
	return newGenerator(&integerGen{
		kind:    "Int32",
		signed:  true,
		bitSize: 32,
		smin:    math.MinInt32,
		smax:    math.MaxInt32,
	})
}

// Int32Min creates a generator for int32 values >= min
func Int32Min(min int32) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int32",
		signed:  true,
		bitSize: 32,
		smin:    int64(min),
		smax:    math.MaxInt32,
		hasMin:  true,
	})
}

// Int32Max creates a generator for int32 values <= max
func Int32Max(max int32) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int32",
		signed:  true,
		bitSize: 32,
		smin:    math.MinInt32,
		smax:    int64(max),
		hasMax:  true,
	})
}

// Int32Range creates a generator for int32 values in [min, max]
func Int32Range(min int32, max int32) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Int32",
		signed:  true,
		bitSize: 32,
		smin:    int64(min),
		smax:    int64(max),
		hasMin:  true,
		hasMax:  true,
	})
}

// Int64 creates a generator for int64 values
func Int64() *Generator {
	return newGenerator(&integerGen{
		kind:    "Int64",
		signed:  true,
		bitSize: 64,
		smin:    math.MinInt64,
		smax:    math.MaxInt64,
	})
}

// Int64Min creates a generator for int64 values >= min
func Int64Min(min int64) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int64",
		signed:  true,
		bitSize: 64,
		smin:    min,
		smax:    math.MaxInt64,
		hasMin:  true,
	})
}

// Int64Max creates a generator for int64 values <= max
func Int64Max(max int64) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int64",
		signed:  true,
		bitSize: 64,
		smin:    math.MinInt64,
		smax:    max,
		hasMax:  true,
	})
}

// Int64Range creates a generator for int64 values in [min, max]
func Int64Range(min int64, max int64) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Int64",
		signed:  true,
		bitSize: 64,
		smin:    min,
		smax:    max,
		hasMin:  true,
		hasMax:  true,
	})
}

// Int creates a generator for int values
func Int() *Generator {
	return newGenerator(&integerGen{
		kind:    "Int",
		signed:  true,
		bitSize: 0,
		smin:    math.MinInt64,
		smax:    math.MaxInt64,
	})
}

// IntMin creates a generator for int values >= min
func IntMin(min int) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int",
		signed:  true,
		bitSize: 0,
		smin:    int64(min),
		smax:    math.MaxInt64,
		hasMin:  true,
	})
}

// IntMax creates a generator for int values <= max
func IntMax(max int) *Generator {
	return newGenerator(&integerGen{
		kind:    "Int",
		signed:  true,
		bitSize: 0,
		smin:    math.MinInt64,
		smax:    int64(max),
		hasMax:  true,
	})
}

// IntRange creates a generator for int values in [min, max]
func IntRange(min int, max int) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Int",
		signed:  true,
		bitSize: 0,
		smin:    int64(min),
		smax:    int64(max),
		hasMin:  true,
		hasMax:  true,
	})
}

// Uint8 creates a generator for uint8 values
func Uint8() *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint8",
		signed:  false,
		umin:    0,
		umax:    math.MaxUint8,
		bitSize: 8,
	})
}

// Uint8Min creates a generator for uint8 values >= min
func Uint8Min(min uint8) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint8",
		signed:  false,
		umin:    uint64(min),
		umax:    math.MaxUint8,
		hasMin:  true,
		bitSize: 8,
	})
}

// Uint8Max creates a generator for uint8 values <= max
func Uint8Max(max uint8) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint8",
		signed:  false,
		umin:    0,
		umax:    uint64(max),
		hasMax:  true,
		bitSize: 8,
	})
}

// Uint8Range creates a generator for uint8 values in [min, max]
func Uint8Range(min uint8, max uint8) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Uint8",
		signed:  false,
		umin:    uint64(min),
		umax:    uint64(max),
		hasMin:  true,
		hasMax:  true,
		bitSize: 8,
	})
}

// Uint16 creates a generator for uint16 values
func Uint16() *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint16",
		signed:  false,
		umin:    0,
		umax:    math.MaxUint16,
		bitSize: 16,
	})
}

// Uint16Min creates a generator for uint16 values >= min
func Uint16Min(min uint16) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint16",
		signed:  false,
		umin:    uint64(min),
		umax:    math.MaxUint16,
		hasMin:  true,
		bitSize: 16,
	})
}

// Uint16Max creates a generator for uint16 values <= max
func Uint16Max(max uint16) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint16",
		signed:  false,
		umin:    0,
		umax:    uint64(max),
		hasMax:  true,
		bitSize: 16,
	})
}

// Uint16Range creates a generator for uint16 values in [min, max]
func Uint16Range(min uint16, max uint16) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Uint16",
		signed:  false,
		umin:    uint64(min),
		umax:    uint64(max),
		hasMin:  true,
		hasMax:  true,
		bitSize: 16,
	})
}

// Uint32 creates a generator for uint32 values
func Uint32() *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint32",
		signed:  false,
		umin:    0,
		umax:    math.MaxUint32,
		bitSize: 32,
	})
}

// Uint32Min creates a generator for uint32 values >= min
func Uint32Min(min uint32) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint32",
		signed:  false,
		umin:    uint64(min),
		umax:    math.MaxUint32,
		hasMin:  true,
		bitSize: 32,
	})
}

// Uint32Max creates a generator for uint32 values <= max
func Uint32Max(max uint32) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint32",
		signed:  false,
		umin:    0,
		umax:    uint64(max),
		hasMax:  true,
		bitSize: 32,
	})
}

// Uint32Range creates a generator for uint32 values in [min, max]
func Uint32Range(min uint32, max uint32) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Uint32",
		signed:  false,
		umin:    uint64(min),
		umax:    uint64(max),
		hasMin:  true,
		hasMax:  true,
		bitSize: 32,
	})
}

// Uint64 creates a generator for uint64 values
func Uint64() *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint64",
		signed:  false,
		umin:    0,
		umax:    math.MaxUint64,
		bitSize: 64,
	})
}

// Uint64Min creates a generator for uint64 values >= min
func Uint64Min(min uint64) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint64",
		signed:  false,
		umin:    min,
		umax:    math.MaxUint64,
		hasMin:  true,
		bitSize: 64,
	})
}

// Uint64Max creates a generator for uint64 values <= max
func Uint64Max(max uint64) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint64",
		signed:  false,
		umin:    0,
		umax:    max,
		hasMax:  true,
		bitSize: 64,
	})
}

// Uint64Range creates a generator for uint64 values in [min, max]
func Uint64Range(min uint64, max uint64) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Uint64",
		signed:  false,
		umin:    min,
		umax:    max,
		hasMin:  true,
		hasMax:  true,
		bitSize: 64,
	})
}

// Uint creates a generator for uint values
func Uint() *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint",
		signed:  false,
		umin:    0,
		umax:    math.MaxUint64,
		bitSize: 0,
	})
}

// UintMin creates a generator for uint values >= min
func UintMin(min uint) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint",
		signed:  false,
		umin:    uint64(min),
		umax:    math.MaxUint64,
		hasMin:  true,
		bitSize: 0,
	})
}

// UintMax creates a generator for uint values <= max
func UintMax(max uint) *Generator {
	return newGenerator(&integerGen{
		kind:    "Uint",
		signed:  false,
		umin:    0,
		umax:    uint64(max),
		hasMax:  true,
		bitSize: 0,
	})
}

// UintRange creates a generator for uint values in [min, max]
func UintRange(min uint, max uint) *Generator {
	assertf(min <= max, "invalid integer range [%v, %v]", min, max)
	return newGenerator(&integerGen{
		kind:    "Uint",
		signed:  false,
		umin:    uint64(min),
		umax:    uint64(max),
		hasMin:  true,
		hasMax:  true,
		bitSize: 0,
	})
}

// Byte creates a generator for byte values (alias for Uint8)
func Byte() *Generator {
	return Uint8()
}

// ByteMin creates a generator for byte values >= min
func ByteMin(min byte) *Generator {
	return Uint8Min(min)
}

// ByteMax creates a generator for byte values <= max
func ByteMax(max byte) *Generator {
	return Uint8Max(max)
}

// ByteRange creates a generator for byte values in [min, max]
func ByteRange(min byte, max byte) *Generator {
	return Uint8Range(min, max)
}
