package fuzzing

// Integer generators and methods.
// Provides generators for all integer types (int, int8-64, uint, uint8-64).

// Type definitions

type intRangeGen struct {
	min int
	max int
}

type int64RangeGen struct {
	min int64
	max int64
}

type int32RangeGen struct {
	min int32
	max int32
}

type int16RangeGen struct {
	min int16
	max int16
}

type int8RangeGen struct {
	min int8
	max int8
}

type uintRangeGen struct {
	min uint
	max uint
}

type uint64RangeGen struct {
	min uint64
	max uint64
}

type uint32RangeGen struct {
	min uint32
	max uint32
}

type uint16RangeGen struct {
	min uint16
	max uint16
}

type uint8RangeGen struct {
	min uint8
	max uint8
}

// String methods

func (g *intRangeGen) String() string {
	return sprintf("IntRange(%d, %d)", g.min, g.max)
}

func (g *int64RangeGen) String() string {
	return sprintf("Int64Range(%d, %d)", g.min, g.max)
}

func (g *int32RangeGen) String() string {
	return sprintf("Int32Range(%d, %d)", g.min, g.max)
}

func (g *int16RangeGen) String() string {
	return sprintf("Int16Range(%d, %d)", g.min, g.max)
}

func (g *int8RangeGen) String() string {
	return sprintf("Int8Range(%d, %d)", g.min, g.max)
}

func (g *uintRangeGen) String() string {
	return sprintf("UintRange(%d, %d)", g.min, g.max)
}

func (g *uint64RangeGen) String() string {
	return sprintf("Uint64Range(%d, %d)", g.min, g.max)
}

func (g *uint32RangeGen) String() string {
	return sprintf("Uint32Range(%d, %d)", g.min, g.max)
}

func (g *uint16RangeGen) String() string {
	return sprintf("Uint16Range(%d, %d)", g.min, g.max)
}

func (g *uint8RangeGen) String() string {
	return sprintf("Uint8Range(%d, %d)", g.min, g.max)
}

// value methods

func (g *intRangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int(v)
}

func (g *int64RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, g.min, g.max, true)
	return v
}

func (g *int32RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int32(v)
}

func (g *int16RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int16(v)
}

func (g *int8RangeGen) value(t *T) any {
	v, _, _ := genIntRange(t.s, int64(g.min), int64(g.max), true)
	return int8(v)
}

func (g *uintRangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint(v)
}

func (g *uint64RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, g.min, g.max, true)
	return v
}

func (g *uint32RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint32(v)
}

func (g *uint16RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint16(v)
}

func (g *uint8RangeGen) value(t *T) any {
	v, _, _ := genUintRange(t.s, uint64(g.min), uint64(g.max), true)
	return uint8(v)
}

// Generator constructors

// IntRange creates a generator for integers in [min, max].
func IntRange(min, max int) *Generator {
	return newGenerator(&intRangeGen{min: min, max: max})
}

// Int64Range creates a generator for int64 in [min, max].
func Int64Range(min, max int64) *Generator {
	return newGenerator(&int64RangeGen{min: min, max: max})
}

// Int32Range creates a generator for int32 in [min, max].
func Int32Range(min, max int32) *Generator {
	return newGenerator(&int32RangeGen{min: min, max: max})
}

// Int16Range creates a generator for int16 in [min, max].
func Int16Range(min, max int16) *Generator {
	return newGenerator(&int16RangeGen{min: min, max: max})
}

// Int8Range creates a generator for int8 in [min, max].
func Int8Range(min, max int8) *Generator {
	return newGenerator(&int8RangeGen{min: min, max: max})
}

// UintRange creates a generator for uints in [min, max].
func UintRange(min, max uint) *Generator {
	return newGenerator(&uintRangeGen{min: min, max: max})
}

// Uint64Range creates a generator for uint64 in [min, max].
func Uint64Range(min, max uint64) *Generator {
	return newGenerator(&uint64RangeGen{min: min, max: max})
}

// Uint32Range creates a generator for uint32 in [min, max].
func Uint32Range(min, max uint32) *Generator {
	return newGenerator(&uint32RangeGen{min: min, max: max})
}

// Uint16Range creates a generator for uint16 in [min, max].
func Uint16Range(min, max uint16) *Generator {
	return newGenerator(&uint16RangeGen{min: min, max: max})
}

// Uint8Range creates a generator for uint8 in [min, max].
func Uint8Range(min, max uint8) *Generator {
	return newGenerator(&uint8RangeGen{min: min, max: max})
}

// T convenience methods

// IntRange generates an int in [min, max].
func (t *T) IntRange(min, max int) int {
	return IntRange(min, max).value(t).(int)
}

// Int64Range generates an int64 in [min, max].
func (t *T) Int64Range(min, max int64) int64 {
	return Int64Range(min, max).value(t).(int64)
}

// Int32Range generates an int32 in [min, max].
func (t *T) Int32Range(min, max int32) int32 {
	return Int32Range(min, max).value(t).(int32)
}

// Int16Range generates an int16 in [min, max].
func (t *T) Int16Range(min, max int16) int16 {
	return Int16Range(min, max).value(t).(int16)
}

// Int8Range generates an int8 in [min, max].
func (t *T) Int8Range(min, max int8) int8 {
	return Int8Range(min, max).value(t).(int8)
}

// UintRange generates a uint in [min, max].
func (t *T) UintRange(min, max uint) uint {
	return UintRange(min, max).value(t).(uint)
}

// Uint64Range generates a uint64 in [min, max].
func (t *T) Uint64Range(min, max uint64) uint64 {
	return Uint64Range(min, max).value(t).(uint64)
}

// Uint32Range generates a uint32 in [min, max].
func (t *T) Uint32Range(min, max uint32) uint32 {
	return Uint32Range(min, max).value(t).(uint32)
}

// Uint16Range generates a uint16 in [min, max].
func (t *T) Uint16Range(min, max uint16) uint16 {
	return Uint16Range(min, max).value(t).(uint16)
}

// Uint8Range generates a uint8 in [min, max].
func (t *T) Uint8Range(min, max uint8) uint8 {
	return Uint8Range(min, max).value(t).(uint8)
}
