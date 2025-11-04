package fuzzing

import "math"

// Combinator generators and methods.
// Provides generators for combining, transforming, and selecting from other generators.

// Generator constructors

// Map transforms values from one generator to another.
// Equivalent to rapid.Map function.
//
// Example:
//
//	doubleGen := Map(IntRange(0, 50), func(v any) any {
//	    return v.(int) * 2
//	})
func Map(gen *Generator, fn func(any) any) *Generator {
	return newGenerator(&mappedGen{
		gen: gen,
		fn:  fn,
	})
}

// Just creates a generator that always returns the same value.
// Equivalent to rapid.Just.
func Just(val any) *Generator {
	return SampledFrom([]any{val})
}

// SampledFrom creates a generator that randomly selects from a slice.
// Equivalent to rapid.SampledFrom.
func SampledFrom(slice []any) *Generator {
	assertf(len(slice) > 0, "SampledFrom: slice must not be empty")

	return newGenerator(&sampledGen{
		slice: slice,
	})
}

// OneOf randomly selects one of the provided generators.
// Equivalent to rapid.OneOf.
func OneOf(gens ...*Generator) *Generator {
	assertf(len(gens) > 0, "OneOf: at least one generator required")

	return newGenerator(&oneOfGen{
		gens: gens,
	})
}

// Filter creates a generator producing only values satisfying the predicate.
// Equivalent to rapid's Generator.Filter method.
//
// Example:
//
//	evenGen := Filter(IntRange(0, 100), func(v any) bool {
//	    return v.(int) % 2 == 0
//	})
func Filter(gen *Generator, predicate func(any) bool) *Generator {
	return newGenerator(&filteredGen{
		gen:       gen,
		predicate: predicate,
	})
}

// Custom creates a generator from a custom function.
// Equivalent to rapid.Custom.
//
// Example:
//
//	gen := Custom(func(t *T) any {
//	    x := t.IntRange(0, 10)
//	    y := t.IntRange(0, 10)
//	    return Point{x, y}
//	})
func Custom(fn func(*T) any) *Generator {
	return newGenerator(&customGen{
		fn: fn,
	})
}

// Deferred creates a generator that is initialized lazily.
// Useful for recursive generators.
// Equivalent to rapid.Deferred.
//
// Example:
//
//	var treeGen *Generator
//	treeGen = Deferred(func() *Generator {
//	    return OneOf(
//	        Just(nil),
//	        Map(SliceOf(treeGen), func(v any) any {
//	            return &Node{Children: v.([]any)}
//	        }),
//	    )
//	})
func Deferred(fn func() *Generator) *Generator {
	return newGenerator(&deferredGen{
		fn: fn,
	})
}

// Permutation creates a generator producing permutations of a slice.
// Equivalent to rapid.Permutation.
func Permutation(slice []any) *Generator {
	return newGenerator(&permGen{
		slice: slice,
	})
}

// T convenience methods

// SampledFrom randomly selects from the given slice.
func (t *T) SampledFrom(slice []any) any {
	return SampledFrom(slice).value(t)
}

// OneOf randomly selects one of the given generators.
func (t *T) OneOf(gens ...*Generator) any {
	return OneOf(gens...).value(t)
}

// Permutation generates a permutation of the given slice.
func (t *T) Permutation(slice []any) []any {
	return Permutation(slice).value(t).([]any)
}

// Repeat executes a function multiple times with varying count.
// The function should return false to reject an iteration.
//
// Example:
//
//	ft.Repeat(1, 10, func() bool {
//	    x := ft.IntRange(0, 100)
//	    return x > 0  // Reject zeros
//	})
func (t *T) Repeat(minCount, maxCount int, fn func() bool) {
	r := newRepeat(minCount, maxCount, -1, "repeat")
	for r.more(t.s) {
		if !fn() {
			r.reject()
		}
	}
}

// RepeatAvg executes a function with a target average count.
func (t *T) RepeatAvg(minCount, maxCount int, avgCount float64, fn func() bool) {
	r := newRepeat(minCount, maxCount, avgCount, "repeat")
	for r.more(t.s) {
		if !fn() {
			r.reject()
		}
	}
}

// String methods

func (g *mappedGen) String() string {
	return "Map(" + g.gen.String() + ")"
}

func (g *sampledGen) String() string {
	if len(g.slice) == 1 {
		return "Just"
	}
	return "SampledFrom"
}

func (g *oneOfGen) String() string {
	return "OneOf"
}

func (g *filteredGen) String() string {
	return g.gen.String() + ".Filter"
}

func (g *customGen) String() string {
	return "Custom"
}

func (g *deferredGen) String() string {
	return "Deferred"
}

func (g *permGen) String() string {
	return "Permutation"
}

// value methods

func (g *mappedGen) value(t *T) any {
	return g.fn(g.gen.value(t))
}

func (g *sampledGen) value(t *T) any {
	i := genIndex(t.s, len(g.slice), true)
	return g.slice[i]
}

func (g *oneOfGen) value(t *T) any {
	i := genIndex(t.s, len(g.gens), true)
	return g.gens[i].value(t)
}

func (g *filteredGen) value(t *T) any {
	return find(g.maybeValue, t, small)
}

func (g *filteredGen) maybeValue(t *T) (any, bool) {
	v := g.gen.value(t)
	if g.predicate(v) {
		return v, true
	}
	return nil, false
}

func (g *customGen) value(t *T) any {
	return find(g.maybeValue, t, small)
}

func (g *customGen) maybeValue(t *T) (any, bool) {
	// Create a temporary T for the custom function
	// This allows catching invalid data exceptions
	defer func() {
		if r := recover(); r != nil {
			if _, ok := r.(invalidData); !ok {
				panic(r)
			}
		}
	}()

	return g.fn(t), true
}

func (g *deferredGen) value(t *T) any {
	if g.gen == nil {
		g.gen = g.fn()
	}
	return g.gen.value(t)
}

func (g *permGen) value(t *T) any {
	s := make([]any, len(g.slice))
	copy(s, g.slice)

	n := len(s)
	m := n - 1
	if m < 0 {
		m = 0
	}

	// Fisher-Yates shuffle with repeat controller for shrinking
	repeat := newRepeat(0, m, math.MaxInt, "permute")
	for i := 0; repeat.more(t.s); i++ {
		j, _, _ := genUintRange(t.s, uint64(i), uint64(n-1), false)
		s[i], s[j] = s[j], s[i]
	}

	return s
}

// Type definitions

type mappedGen struct {
	gen *Generator
	fn  func(any) any
}

type sampledGen struct {
	slice []any
}

type oneOfGen struct {
	gens []*Generator
}

type filteredGen struct {
	gen       *Generator
	predicate func(any) bool
}

type customGen struct {
	fn func(*T) any
}

type deferredGen struct {
	gen *Generator
	fn  func() *Generator
}

type permGen struct {
	slice []any
}
