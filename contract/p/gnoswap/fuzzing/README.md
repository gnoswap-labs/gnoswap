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
- `Int8Range(min, max)` - int8 in [min, max]
- `Int16Range(min, max)` - int16 in [min, max]
- `Int32Range(min, max)` - int32 in [min, max]
- `Int64Range(min, max)` - int64 in [min, max]
- `UintRange(min, max)` - uint in [min, max]
- `Uint8Range(min, max)` - uint8 in [min, max]
- `Uint16Range(min, max)` - uint16 in [min, max]
- `Uint32Range(min, max)` - uint32 in [min, max]
- `Uint64Range(min, max)` - uint64 in [min, max]

**Floating Point:**
- `Float32Range(min, max)` - float32 in [min, max] (biased towards 0, min, max)
- `Float64Range(min, max)` - float64 in [min, max] (biased towards 0, min, max)

**Primitives:**
- `Bool()` - random boolean (50/50)
- `Byte()` - random byte [0, 255]
- `ByteRange(min, max)` - byte in [min, max]
- `Rune()` - valid Unicode code point
- `RuneRange(min, max)` - rune in [min, max]

**Strings:**
- `String()` - string with length [0, 100]
- `StringN(minLen, maxLen)` - string with custom length bounds
- `StringOf(runeGen)` - string from custom rune generator
- `StringOfN(runeGen, minLen, maxLen)` - string from custom rune generator with length bounds

**Collections:**
- `SliceOf(elemGen)` - slice with length [0, 100]
- `SliceOfN(elemGen, minLen, maxLen)` - slice with custom length bounds
- `SliceOfDistinct(elemGen, keyFn)` - slice with distinct elements
- `SliceOfNDistinct(elemGen, minLen, maxLen, keyFn)` - slice with distinct elements and length bounds
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

### Testing with Float Values

```go
func TestFloatCalculation(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        price := ft.Float64Range(0.01, 1000.0)
        amount := ft.Float64Range(1.0, 100.0)
        
        total := price * amount
        
        // Property: total should be positive
        if total <= 0 {
            ft.Fatalf("total should be positive: %f", total)
        }
    })
}
```

### Testing with Custom Rune Generators

```go
func TestHexString(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        // Generate strings with only hex characters
        hexRune := ft.SampledFrom([]any{
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
            'a', 'b', 'c', 'd', 'e', 'f',
        }).(rune)
        
        hexGen := fuzzing.RuneRange('0', 'f') // Simplified for example
        hexStr := ft.StringOfN(hexGen, 8, 16)
        
        // Property: should be valid hex
        if len(hexStr) < 8 || len(hexStr) > 16 {
            ft.Fatalf("invalid hex string length: %d", len(hexStr))
        }
    })
}
```

### Testing with Distinct Collections

```go
func TestUniqueIDs(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        // Generate slice of distinct IDs
        ids := ft.SliceOfNDistinct(
            fuzzing.IntRange(1, 100),
            5, 10,
            nil, // use elements directly as keys
        )
        
        // Verify all IDs are unique
        seen := make(map[int]bool)
        for _, id := range ids {
            val := id.(int)
            if seen[val] {
                ft.Fatalf("duplicate ID: %d", val)
            }
            seen[val] = true
        }
    })
}

// Testing with custom key function
type User struct {
    ID   int
    Name string
}

func TestUniqueUsers(t *testing.T) {
    fuzzing.Check(t, func(ft *fuzzing.T) {
        userGen := fuzzing.Custom(func(ft *fuzzing.T) any {
            return User{
                ID:   ft.IntRange(1, 50),
                Name: ft.String(),
            }
        })
        
        // Generate distinct users by ID
        users := ft.SliceOfNDistinct(
            userGen,
            3, 8,
            func(v any) any { return v.(User).ID }, // key by ID
        )
        
        // All user IDs should be unique
        seenIDs := make(map[int]bool)
        for _, u := range users {
            user := u.(User)
            if seenIDs[user.ID] {
                ft.Fatalf("duplicate user ID: %d", user.ID)
            }
            seenIDs[user.ID] = true
        }
    })
}
```

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
- **Primitives**: Int, Int8/16/32/64, Uint, Uint8/16/32/64, Float32/64, Bool, Byte, Rune, String
- **Collections**: Slice, SliceOfDistinct, Map
- **Strings**: String, StringN, StringOf, StringOfN (with custom rune generators)
- **Combinators**: Map, Filter, Custom, Deferred, Just, SampledFrom, OneOf, Permutation
- **Repetition**: Repeat, RepeatAvg

**Features:**
- All numeric types with Range variants
- Float generation with bias towards boundaries and zero
- Custom rune generators for constrained strings
- Distinct element generation with custom key functions
- Biased generation for better edge case discovery

### ❌ Not Implemented Yet

- **Shrinking**: Automatic test case minimization (infrastructure in place, algorithm pending)
- **State machines**: Structured stateful testing with StateMachine interface
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
├── bitstream.gno       # Core bitstream + JSF64 PRNG
├── utils.gno           # Generation utilities + float helpers
├── generator.gno       # Generator interface + combinators
├── fuzzing.gno         # Main API: Check, T, Config
├── primitives.gno      # All numeric types, strings, runes
├── collections.gno     # Slice, Map, Distinct variants
└── README.md           # This file
```

## License

Part of Gnoswap project.
