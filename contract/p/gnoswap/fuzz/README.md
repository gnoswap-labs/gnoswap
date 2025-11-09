# Fuzz Package

A property-based testing and fuzz library for Gno, ported from [rapid](https://github.com/flyingmutant/rapid).

## License

This package is derived from the rapid library and is licensed under the Mozilla Public License Version 2.0 (MPL 2.0).

Original copyright: Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>

## Overview

This fuzz package provides generators for property-based testing in Gno smart contracts. It allows you to:

- Generate random test data for various types
- Create complex data structures with constraints
- Test stateful systems with state machine testing
- Combine and transform generators

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
    // Automatically runs random test cases
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
- **Floats**:
  - **float32**: `Float32()`, `Float32Min()`, `Float32Max()`, `Float32Range()`
  - **float64**: `Float64()`, `Float64Min()`, `Float64Max()`, `Float64Range()`
- **Strings**: `String()`, `StringN()`, `StringOf()`, `StringOfN()`
- **Runes**: `Rune()`, `RuneFrom()`

#### Collections

- **Slices**: `SliceOf(elem)`, `SliceOfN(elem, minLen, maxLen)`
- **Maps**: `MapOf(key, val)`, `MapOfN(key, val, minLen, maxLen)`

#### Combinators

- `Custom(fn)` - Create custom generators
- `Just(val)` - Always return the same value
- `SampledFrom(slice)` - Sample from a slice
- `OneOf(gens...)` - Choose from multiple generators
- `Map(gen, transform)` - Transform generated values
- `Deferred(fn)` - Lazy generator for recursive structures
- `Permutation(slice)` - Generate permutations

#### Property-Based Testing

- `Check(t, prop)` - Run 100 random test cases
- `CheckN(t, n, prop)` - Run N random test cases

## Basic Usage

### Simple Generators

```go
package mypackage

import "gno.land/p/gnoswap/fuzz"

func TestBasic() {
    seed := uint64(12345)
    s := fuzz.NewRandomBitStream(seed, false)

    // Integers
    intGen := fuzz.Int64Range(0, 100)
    value := intGen.value(s).(int64)

    // Strings
    strGen := fuzz.StringN(5, 10, 20) // 5-10 runes, max 20 bytes
    str := strGen.value(s).(string)

    // Booleans
    boolGen := fuzz.Bool()
    flag := boolGen.value(s).(bool)
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
// Generate slices
elemGen := fuzz.Int32Range(0, 100)
sliceGen := fuzz.SliceOfN(elemGen, 5, 10) // 5-10 elements
slice := sliceGen.value(s).([]any)

// Generate maps
keyGen := fuzz.String()
valGen := fuzz.Int64()
mapGen := fuzz.MapOfN(keyGen, valGen, 3, 5) // 3-5 entries
m := mapGen.value(s).(map[any]any)
```

### Custom Generators

```go
// Create a custom generator for a struct
type Point struct {
    X, Y int64
}

pointGen := fuzz.Custom(func(s bitStream) any {
    x := fuzz.Int64Range(-100, 100).value(s).(int64)
    y := fuzz.Int64Range(-100, 100).value(s).(int64)
    return Point{X: x, Y: y}
})

point := pointGen.value(s).(Point)
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

### Conditional Generation

```go
// Generate different values based on condition
gen := fuzz.Custom(func(s bitStream) any {
    usePositive := fuzz.Bool().value(s).(bool)
    if usePositive {
        return fuzz.Int64Range(1, 100).value(s)
    }
    return fuzz.Int64Range(-100, -1).value(s)
})
```

### Nested Structures

```go
type Address struct {
    Street string
    City   string
    Zip    int32
}

type Person struct {
    Name    string
    Age     int32
    Address Address
}

personGen := fuzz.Custom(func(s bitStream) any {
    name := fuzz.StringN(3, 10, 20).value(s).(string)
    age := fuzz.Int32Range(0, 120).value(s).(int32)

    street := fuzz.StringN(5, 20, 50).value(s).(string)
    city := fuzz.StringN(3, 15, 30).value(s).(string)
    zip := fuzz.Int32Range(10000, 99999).value(s).(int32)

    return Person{
        Name: name,
        Age:  age,
        Address: Address{
            Street: street,
            City:   city,
            Zip:    zip,
        },
    }
})
```

### Recursive Generators

```go
type Tree struct {
    Value int64
    Left  *Tree
    Right *Tree
}

func treeGen(maxDepth int) *fuzz.Generator {
    return fuzz.Custom(func(s bitStream) any {
        value := fuzz.Int64Range(0, 100).value(s).(int64)

        if maxDepth <= 0 {
            return &Tree{Value: value}
        }

        hasLeft := fuzz.Bool().value(s).(bool)
        hasRight := fuzz.Bool().value(s).(bool)

        tree := &Tree{Value: value}
        if hasLeft {
            tree.Left = treeGen(maxDepth - 1).value(s).(*Tree)
        }
        if hasRight {
            tree.Right = treeGen(maxDepth - 1).value(s).(*Tree)
        }

        return tree
    })
}
```

## Best Practices

### 1. Use Appropriate Constraints

```go
// Good: constrained generation
positiveGen := fuzz.Int64Range(1, 1000)
```

### 2. Handle Invalid States Gracefully

```go
actions := []fuzz.Action{
    {
        Name: "RemoveItem",
        Run: func(s bitStream) {
            if len(items) == 0 {
                // Skip this action instead of panicking
                panic(fuzz.invalidData("no items to remove"))
            }
            // ... remove item
        },
    },
}
```

### 3. Write Clear Invariants

```go
check := func(s bitStream) {
    // Clear invariant checks
    if total < 0 {
        panic("total should never be negative")
    }
    if len(items) > maxCapacity {
        panic("items exceed maximum capacity")
    }
    // Verify data consistency
    sum := int64(0)
    for _, item := range items {
        sum += item.value
    }
    if sum != total {
        panic("sum of items doesn't match total")
    }
}
```

### 4. Use Seeds for Reproducibility

```go
// Use consistent seeds for reproducible tests
func TestWithSeed() {
    seeds := []uint64{12345, 67890, 11111}

    for _, seed := range seeds {
        s := fuzz.NewRandomBitStream(seed, false)
        // Run test with this seed
    }
}
```

## API Reference

### Core Types

- `T` - Test context (like rapid's \*T)
- `Generator` - Generates random values
- `bitStream` - Interface for random bit generation
- `Action` - State machine action with name and function
- `StateMachine` - Stateful test runner

### Key Functions

- `newT(s bitStream) *T` - Create test context
- `newRandomBitStream(seed, persist) *randomBitStream` - Create random bit stream
- `newBufBitStream(buf, persist) *bufBitStream` - Create buffered bit stream
- `NewStateMachine(actions, check, steps) *StateMachine` - Create state machine
- `Repeat(s, actions, steps)` - Run state machine with actions map (low-level)

### T Methods (testing.T-like API)

- `Draw(gen *Generator, label string) any` - Generate a value
- `Repeat(actions map[string]func(*T), steps int)` - Run state machine
- `Skip(args ...any)` - Skip current test case
- `SkipNow()` - Skip without logging
- `Skipf(format string, args ...any)` - Skip with formatted message
- `Error(args ...any)` - Mark test as failed, continue
- `Errorf(format string, args ...any)` - Mark test as failed with format, continue
- `Fatal(args ...any)` - Mark test as failed, stop immediately
- `Fatalf(format string, args ...any)` - Mark test as failed with format, stop
- `Fail()` - Mark test as failed, continue
- `FailNow()` - Mark test as failed, stop immediately
- `Failed() bool` - Check if test has failed
- `Log(args ...any)` - Log a message
- `Logf(format string, args ...any)` - Log a formatted message

### Generator Methods

- `value(s bitStream) any` - Generate a value (low-level)
- `Example(seed uint64) any` - Generate example value with seed
- `Map(fn func(any) any) *Generator` - Transform values

## Porting Notes

This package is a port of the [rapid](https://github.com/flyingmutant/rapid) library adapted for Gno. Key differences:

1. **No Generics**: Gno doesn't support generics, so all generators return `any`
2. **No Reflection**: `Make[T]()` and reflection-based features are not available
3. **No Regexp**: `StringMatching()` is not available
4. **Simplified API**: Some advanced features like shrinking and visualization are omitted

### ❌ Not Supported (Gno Limitations)

- Reflection-based generators (`Make[T]()`)
- Regex-based string generation (`StringMatching()`)
- Test case shrinking (minimization)
- Fail file persistence
- Visualization tools

### ⚠️ Known Limitations

1. **No generic types**: All generators return `any` due to Gno's lack of generics
2. **No test case shrinking**: Failing test cases are not automatically minimized
3. **Fixed base seed**: Uses a constant base seed (can be improved with time-based seeding)

## Contributing

When contributing to this package, ensure all code maintains the MPL 2.0 license headers and attribution to the original rapid project.
