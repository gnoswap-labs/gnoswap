# Fuzz Package

A property-based testing and fuzz library for Gno, ported from [rapid](https://github.com/flyingmutant/rapid).

## License

This package is derived from the rapid library and is licensed under the Mozilla Public License Version 2.0 (MPL 2.0).

Original copyright: Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>

## Overview

This fuzz package provides generators for property-based testing in Gno smart contracts. It allows you to:

- Generate random test data for primitive, collection, and 256-bit integer types
- Compose and transform generators
- Check properties over explicitly requested numbers of generated cases

## Quick Start

### Using Check() for Property-Based Testing (Recommended)

```go
import (
    "testing"
    "gno.land/p/gnoswap/fuzz"
)

func TestProperty(t *testing.T) {
    fuzz.Check(t, func(ft *fuzz.T) {
        // Generate random test data
        x := fuzz.Int64Range(0, 100).Draw(ft, "x").(int64)
        y := fuzz.Int64Range(0, 100).Draw(ft, "y").(int64)

        // Test a property
        if x + y != y + x {
            ft.Fatalf("commutativity failed: %d + %d != %d + %d", x, y, y, x)
        }
    })
    // Check runs one case by default; use CheckN for an explicit count.
}
```

### Manual Generator Usage

```go
func TestExample() {
    seed := uint64(12345)

    // Generate integers
    intGen := fuzz.Int64Range(0, 100)
    value := intGen.Example(seed).(int64)

    // Generate strings
    strGen := fuzz.String()
    str := strGen.Example(seed).(string)
}
```

## Core Features

#### Primitives

- **Boolean**: `Bool()`
- **Integers**:
  - **int8**: `Int8()`, `Int8Min()`, `Int8Max()`, `Int8Range()`
  - **int16**: `Int16()`, `Int16Min()`, `Int16Max()`, `Int16Range()`
  - **int32**: `Int32()`, `Int32Min()`, `Int32Max()`, `Int32Range()`
  - **int64**: `Int64()`, `Int64Min()`, `Int64Max()`, `Int64Range()`
  - **int**: `Int()`, `IntMin()`, `IntMax()`, `IntRange()`
  - **uint8**: `Uint8()`, `Uint8Min()`, `Uint8Max()`, `Uint8Range()`, `Byte()`, `ByteMin()`, `ByteMax()`, `ByteRange()`
  - **uint16**: `Uint16()`, `Uint16Min()`, `Uint16Max()`, `Uint16Range()`
  - **uint32**: `Uint32()`, `Uint32Min()`, `Uint32Max()`, `Uint32Range()`
  - **uint64**: `Uint64()`, `Uint64Min()`, `Uint64Max()`, `Uint64Range()`
  - **uint**: `Uint()`, `UintMin()`, `UintMax()`, `UintRange()`
- **256-bit integers**: `Uint256*()` and `Int256*()` generators
- **Floats**:
  - **float32**: `Float32()`, `Float32Min()`, `Float32Max()`, `Float32Range()`
  - **float64**: `Float64()`, `Float64Min()`, `Float64Max()`, `Float64Range()`
- **Strings**: `String()`, `StringN()`, `StringOf()`, `StringOfN()`
- **Runes**: `Rune()`, `RuneFrom()`

#### Collections

- **Slices**: `SliceOf(elem)`, `SliceOfN(elem, minLen, maxLen)`
- **Maps**: `MapOf(key, val)`, `MapOfN(key, val, minLen, maxLen)`

#### Combinators

- `Custom(fn)` - Package-local custom generator (callback uses internal `bitStream`)
- `Just(val)` - Always return the same value
- `SampledFrom(slice)` - Sample from a slice
- `OneOf(gens...)` - Choose from multiple generators
- `Map(gen, transform)` - Transform generated values
- `Deferred(fn)` - Lazily construct a generator when it is drawn
- `Permutation(slice)` - Generate permutations

#### Property-Based Testing

- `Check(t, prop)` - Run one random test case by default
- `CheckN(t, n, prop)` - Run up to N valid random test cases

## Basic Usage

### Generating with Check

```go
package mypackage

import (
    "testing"
    "gno.land/p/gnoswap/fuzz"
)

func TestBasic(t *testing.T) {
    fuzz.CheckN(t, 10, func(ft *fuzz.T) {
        // Draw values through the public Generator API.
        value := fuzz.Int64Range(0, 100).Draw(ft, "value").(int64)
        str := fuzz.StringN(5, 10, 20).Draw(ft, "str").(string)
        flag := fuzz.Bool().Draw(ft, "flag").(bool)
        _, _, _ = value, str, flag
    })
}
```

### Using Example Method

```go
// Generate example values with a seed
intGen := fuzz.Int64Range(0, 100)
value := intGen.Example(12345).(int64)

strGen := fuzz.String()
str := strGen.Example(54321).(string)
```

### Collections

```go
seed := uint64(12345)

elemGen := fuzz.Int32Range(0, 100)
sliceGen := fuzz.SliceOfN(elemGen, 5, 10) // 5-10 elements
slice := sliceGen.Example(seed).([]any)

keyGen := fuzz.String()
valGen := fuzz.Int64()
mapGen := fuzz.MapOfN(keyGen, valGen, 3, 5) // 3-5 entries
m := mapGen.Example(seed).(map[any]any)
```

### Transforming Generated Values

```go
squareGen := fuzz.Int32Range(0, 10).Map(func(v any) any {
    n := v.(int32)
    return n * n
})
square := squareGen.Example(12345).(int32)
```

### Combinators

```go
// Map: transform generated values
squareGen := fuzz.Int32Range(0, 10).Map(func(v any) any {
    n := v.(int32)
    return n * n
})

// SampledFrom: pick from predefined values
colorGen := fuzz.SampledFrom([]any{"red", "green", "blue"})

// OneOf: choose between multiple generators
mixedGen := fuzz.OneOf(
    fuzz.Int32(),
    fuzz.String(),
    fuzz.Float64(),
)

// Just: always return the same value
constGen := fuzz.Just(42)
```

## Advanced Patterns

### Selecting Among Generators

```go
// OneOf selects one of the supplied generators for each example.
numberOrText := fuzz.OneOf(
    fuzz.Int64Range(-100, 100),
    fuzz.StringN(1, 8, 16),
)
value := numberOrText.Example(12345)
```

### Building Derived Values

```go
type Point struct {
    X, Y int64
}

pointGen := fuzz.Int64Range(-100, 100).Map(func(v any) any {
    x := v.(int64)
    return Point{X: x, Y: x}
})
point := pointGen.Example(12345).(Point)
```

### Deferred Generators

```go
// Deferred delays construction until the generator is drawn.
lazyString := fuzz.Deferred(func() *fuzz.Generator {
    return fuzz.String()
})
value := lazyString.Example(12345).(string)
```

## Best Practices

### 1. Use Appropriate Constraints

```go
// Good: constrained generation
positiveGen := fuzz.Int64Range(1, 1000)
```

### 2. Handle Invalid States Gracefully

```go
func TestSkipEmpty(t *testing.T) {
    fuzz.Check(t, func(ft *fuzz.T) {
        count := fuzz.Int32Range(0, 10).Draw(ft, "count").(int32)
        if count == 0 {
            ft.SkipNow()
            return
        }
        ft.Logf("testing a non-empty case with %d items", count)
    })
}
```

### 3. Write Clear Invariants

```go
func TestInvariant(t *testing.T) {
    fuzz.Check(t, func(ft *fuzz.T) {
        value := fuzz.Int64Range(0, 100).Draw(ft, "value").(int64)
        if value < 0 {
            ft.Fatalf("value should never be negative: %d", value)
        }
    })
}
```

### 4. Use Seeds for Reproducibility

```go
// Example uses the supplied seed to reproduce a generated value.
seed := uint64(12345)
value := fuzz.Int64Range(0, 100).Example(seed).(int64)
```

## API Reference

### Core Types

- `TestingT` - Minimal test interface accepted by `Check` and `CheckN`
- `T` - Test context passed to a property callback
- `Generator` - Public generator value

The package also has internal bit-stream and state-machine implementation types;
they are not part of the public API.

### Key Functions

- `Check(t, prop)` - Run one valid random case
- `CheckN(t, n, prop)` - Run up to `n` valid random cases
- Primitive generators such as `Bool`, `Int64Range`, `Uint64Range`, and `StringN`
- 256-bit generators: `Uint256`, `Uint256Min`, `Uint256Max`, `Uint256Range`,
  `Uint256RangeFrom`, and the corresponding `Int256*` functions
- Collection generators: `SliceOf`, `SliceOfN`, `MapOf`, and `MapOfN`
- Combinators: `Map`, `Just`, `SampledFrom`, `OneOf`, `Deferred`, and
  `Permutation`

`Custom` is declared for package-local use, but its callback accepts the
unexported `bitStream` type and cannot be named by external callers.

### T Methods (testing.T-like API)

- `Skip(args ...any)`, `SkipNow()`, and `Skipf(format string, args ...any)`
- `Error(args ...any)`, `Errorf(format string, args ...any)`
- `Fatal(args ...any)`, `Fatalf(format string, args ...any)`
- `Fail()`, `FailNow()`, and `Failed() bool`
- `Log(args ...any)` and `Logf(format string, args ...any)`

### Generator Methods

- `String() string` - Describe the generator
- `Draw(t *T, label string) any` - Generate a value within a property callback
- `Example(seed uint64) any` - Generate a reproducible example value
- `Map(fn func(any) any) *Generator` - Transform generated values

## Porting Notes

This package is a port of the [rapid](https://github.com/flyingmutant/rapid) library adapted for Gno. Key differences:

1. **No Generics**: Gno doesn't support generics, so all generators return `any`
2. **No Reflection**: `Make[T]()` and reflection-based features are not available
3. **No Regexp**: `StringMatching()` is not available
4. **No State-Machine Runner**: The current package exposes property checks and
   generators, not rapid's state-machine API
5. **Simplified API**: Shrinking and visualization features are omitted

### ❌ Not Supported (Gno Limitations)

- Reflection-based generators (`Make[T]()`)
- Regex-based string generation (`StringMatching()`)
- Test case shrinking (minimization)
- Stateful action runners/state-machine tests
- Fail file persistence
- Visualization tools

### ⚠️ Known Limitations

1. **No generic types**: All generators return `any` due to Gno's lack of generics
2. **One case by default**: `Check` runs one valid case; use `CheckN` to request
   a different number of valid cases
3. **Package-local `Custom` callback**: Its `bitStream` parameter is unexported,
   so external callers should use `Map`, `OneOf`, or other public combinators
4. **No test case shrinking**: Failing test cases are not automatically minimized
5. **Fixed base seed**: Uses a constant base seed
6. **Signed 256-bit span cap**: For bounds whose span exceeds `MaxInt256`,
   current `Int256*` generators cap the span and may omit values near the
   requested upper bound.

## Contributing

When contributing to this package, ensure all code maintains the MPL 2.0 license headers and attribution to the original rapid project.
