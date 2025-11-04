# Fuzzing - Property-Based Testing for Gno

A property-based testing library for Gno, implementing bitstream-based random generation inspired by [Rapid](https://github.com/flyingmutant/rapid).

## Features

- **Bitstream-based generation**: Reproducible random value generation for future shrinking support
- **Biased generation**: Prefers small values and edge cases for better bug finding
- **Generator combinators**: Map, Filter, Custom, Deferred for composing generators
- **Clean-room implementation**: Algorithm-based independent implementation for Gno

## Quick Start

```go
import (
    "testing"
    "gno.land/p/gnoswap/fuzzing"
)

func TestAdditionCommutative(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        a := ft.IntRange(-100, 100)
        b := ft.IntRange(-100, 100)

        if a+b != b+a {
            ft.Fatalf("addition not commutative: %d + %d != %d + %d", a, b, b, a)
        }
    })
}
```

## Core API

### Check Function

`Check(t *testing.T, property func(*T))` - Main entry point for property-based testing.

```go
fuzzing.Check(t, func(ft *fuzzing.T) {
    n := ft.IntRange(0, 100)
    s := ft.String()

    if !someProperty(n, s) {
        ft.Fatalf("property violated")
    }
})
```

### Configuration

Customize test behavior with `CheckWithConfig`:

```go
config := &fuzzing.Config{
    BaseSeed:   12345,      // deterministic seed (0 = random)
    Iterations: 200,        // number of test cases (default: 100)
    Verbose:    true,       // detailed output
}

fuzzing.CheckWithConfig(t, config, func(ft *fuzzing.T) {
    // Property test
})
```

## Available Generators

### T Convenience Methods

The `*T` context provides convenience methods for generating values:

**Integers:**
- `IntRange(min, max)` - int in [min, max]
- `Int64Range(min, max)` - int64 in [min, max]
- `UintRange(min, max)` - uint in [min, max]
- `Uint64Range(min, max)` - uint64 in [min, max]

**Primitives:**
- `Bool()` - random boolean (50/50)
- `Byte()` - random byte [0, 255]
- `ByteRange(min, max)` - byte in [min, max]
- `Rune()` - valid Unicode code point
- `RuneRange(min, max)` - rune in [min, max]

**Strings:**
- `String()` - string with length [0, 100]
- `StringN(minLen, maxLen)` - string with custom length bounds

**Collections:**
- `SliceOf(elemGen)` - slice with length [0, 100]
- `SliceOfN(elemGen, minLen, maxLen)` - slice with custom length bounds
- `MapOf(keyGen, valueGen)` - map with size [0, 100]
- `MapOfN(keyGen, valueGen, minSize, maxSize)` - map with custom size bounds

**Selection:**
- `SampledFrom(slice)` - randomly select from slice
- `OneOf(generators...)` - randomly select from generators
- `Permutation(slice)` - random permutation of slice

**Repetition:**
- `Repeat(minCount, maxCount, fn)` - execute function with varying count
- `RepeatAvg(minCount, maxCount, avgCount, fn)` - execute with target average

### Generator Constructors

Create reusable generators:

```go
// Primitives
gen := fuzzing.IntRange(0, 100)
gen := fuzzing.Bool()
gen := fuzzing.String()
gen := fuzzing.ByteRange(0, 255)

// Collections
gen := fuzzing.SliceOf(fuzzing.IntRange(0, 100))
gen := fuzzing.MapOf(fuzzing.String(), fuzzing.IntRange(0, 100))

// Selection
gen := fuzzing.Just(42)  // constant value
gen := fuzzing.SampledFrom([]any{1, 2, 3, 4})
gen := fuzzing.OneOf(gen1, gen2, gen3)
gen := fuzzing.Permutation([]any{1, 2, 3})
```

### Generator Combinators

Transform and constrain generators:

```go
// Map: transform generated values
doubleGen := fuzzing.Map(
    fuzzing.IntRange(0, 50),
    func(v any) any { return v.(int) * 2 },
)

// Filter: constrain to valid values
evenGen := fuzzing.Filter(
    fuzzing.IntRange(0, 100),
    func(v any) bool { return v.(int)%2 == 0 },
)

// Custom: define custom generation logic
customGen := fuzzing.Custom(func(t *fuzzing.T) any {
    x := t.IntRange(0, 10)
    y := t.IntRange(0, 10)
    return Point{X: x, Y: y}
})

// Deferred: lazy initialization for recursive structures
var treeGen *fuzzing.Generator
treeGen = fuzzing.Deferred(func() *fuzzing.Generator {
    return fuzzing.OneOf(
        fuzzing.Just(nil),  // leaf
        fuzzing.Map(fuzzing.SliceOf(treeGen), func(v any) any {
            return &Node{Children: v.([]any)}
        }),
    )
})
```

### Using Generators with T.Draw

```go
fuzzing.Check(t, func(ft *fuzzing.T) {
    gen := fuzzing.IntRange(0, 100)
    n := ft.Draw(gen).(int)  // explicit type assertion needed

    // Use n
})
```

## Examples

### Testing Pool Swap Invariants

```go
func TestPoolSwapInvariant(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        // Setup initial state
        initialBalance0 := ft.Uint64Range(1000, 1000000)
        initialBalance1 := ft.Uint64Range(1000, 1000000)
        pool := NewPool(initialBalance0, initialBalance1)

        // Perform swap
        swapAmount := ft.Uint64Range(1, initialBalance0/10)
        result := pool.Swap(swapAmount, true)

        // Check invariant: k = x * y should not decrease (fees increase it)
        if pool.K() < initialBalance0*initialBalance1 {
            ft.Fatalf("k invariant violated: %d < %d",
                pool.K(), initialBalance0*initialBalance1)
        }
    })
}
```

### Testing String Concatenation

```go
func TestStringConcatLength(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        s1 := ft.String()
        s2 := ft.String()

        result := s1 + s2

        if len(result) != len(s1)+len(s2) {
            ft.Fatalf("length mismatch: len(%q + %q) = %d, want %d",
                s1, s2, len(result), len(s1)+len(s2))
        }
    })
}
```

### Testing With Repeat

```go
func TestStackOperations(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        stack := NewStack()

        ft.Repeat(1, 20, func() bool {
            action := ft.SampledFrom([]any{"push", "pop"}).(string)

            switch action {
            case "push":
                val := ft.IntRange(0, 100)
                stack.Push(val)
            case "pop":
                if !stack.IsEmpty() {
                    stack.Pop()
                }
            }

            // Invariant check
            if stack.Size() < 0 {
                ft.Fatal("negative stack size")
            }

            return true  // accept all iterations
        })
    })
}
```

### Testing Recursive Structures

```go
type Tree struct {
    Value    int
    Children []*Tree
}

func TestTreeDepth(t *testing.T) {
    var treeGen *fuzzing.Generator
    treeGen = fuzzing.Deferred(func() *fuzzing.Generator {
        return fuzzing.OneOf(
            // Leaf node
            fuzzing.Custom(func(ft *fuzzing.T) any {
                return &Tree{Value: ft.IntRange(0, 100)}
            }),
            // Branch node (recursive)
            fuzzing.Custom(func(ft *fuzzing.T) any {
                children := ft.SliceOfN(treeGen, 1, 3).([]any)
                treeChildren := make([]*Tree, len(children))
                for i, c := range children {
                    treeChildren[i] = c.(*Tree)
                }
                return &Tree{
                    Value:    ft.IntRange(0, 100),
                    Children: treeChildren,
                }
            }),
        )
    })

    fuzzing.Check(t, func(ft *fuzzing.T) {
        tree := ft.Draw(treeGen).(*Tree)

        depth := calculateDepth(tree)
        if depth > 100 {
            ft.Fatalf("tree too deep: %d", depth)
        }
    })
}
```

## Implementation Status

### ✅ Implemented

**Core Infrastructure:**
- Bitstream pattern with JSF64 PRNG
- Recording and replay for future shrinking
- Biased generation (prefers 0, 1, small values)
- Geometric distribution for natural sizes

**Generators:**
- Primitives: Int, Uint, Bool, Byte, Rune, String (all with Range variants)
- Collections: Slice, Map
- Combinators: Map, Filter, Custom, Deferred, Just, SampledFrom, OneOf, Permutation
- Repetition: Repeat, RepeatAvg

**Testing:**
- Comprehensive test coverage (950+ lines of tests)
- All tests passing
- Bitstream, utils, and generator modules fully tested

### ❌ Not Implemented Yet

- **Shrinking**: Automatic test case minimization (infrastructure in place, algorithm pending)
- **State machines**: Structured stateful testing with Check() method
- **Additional types**: Int8/16/32, Uint8/16/32, Float32/64
- **Advanced strings**: StringOf with custom rune generators
- **Distinct collections**: SliceOfDistinct, SliceOfNDistinct
- **Gnoswap types**: Uint256, Int256 domain-specific generators

### ❌ Not Available (Gno Limitations)

- **Generics**: Gno doesn't support generics - using `any` type instead
- **Reflection**: No auto-generation of actions or values
- **Regex**: No StringMatching generators
- **Go fuzzing integration**: No coverage-guided fuzzing (use Check() instead)

## Differences from Rapid

1. **No Generics**:
   ```go
   // Rapid (Go)
   n := rapid.IntRange(0, 100).Draw(t, "n")  // type-safe

   // This library (Gno)
   n := ft.IntRange(0, 100)  // returns int directly
   // or with explicit generator:
   n := ft.Draw(IntRange(0, 100)).(int)  // needs type assertion
   ```

2. **Clean-room Implementation**: Algorithm-based implementation, not a port
3. **Simplified API**: Fewer generator variants, focus on core functionality
4. **No Shrinking Yet**: Infrastructure ready, minimization algorithm pending
5. **Modular Design**: Separated into bitstream, utils, generator, primitives, collections

## Architecture

```
fuzzing/
├── bitstream.gno       # Core bitstream + JSF64 PRNG (245 lines)
├── utils.gno           # Generation utilities (246 lines)
├── generator.gno       # Generator interface + combinators (293 lines)
├── fuzzing.gno         # Main API: Check, T, Config (253 lines)
├── primitives.gno      # Int, String, Bool, Byte, Rune (212 lines)
├── collections.gno     # Slice, Map (74 lines)
└── *_test.gno          # Comprehensive tests (950+ lines)
```

## License

Part of Gnoswap project.
