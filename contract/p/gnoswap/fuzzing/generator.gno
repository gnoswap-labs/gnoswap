package fuzzing

import "math"

// generatorImpl is the internal interface for generators.
// Since Gno doesn't support generics, we use 'any' type.
type generatorImpl interface {
	String() string
	value(t *T) any
}

// Generator produces values for property-based testing.
// In Rapid this is Generic[V any], but Gno doesn't support generics.
type Generator struct {
	impl generatorImpl
	str  string
}

// newGenerator creates a new Generator from an implementation.
func newGenerator(impl generatorImpl) *Generator {
	return &Generator{
		impl: impl,
		str:  impl.String(),
	}
}

// String returns a string representation of the generator.
func (g *Generator) String() string {
	return g.str
}

// value generates a value using the bitstream from T.
func (g *Generator) value(t *T) any {
	i := t.s.beginGroup(g.str, true)
	v := g.impl.value(t)
	t.s.endGroup(i, false)
	return v
}

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

type mappedGen struct {
	gen *Generator
	fn  func(any) any
}

func (g *mappedGen) String() string {
	return "Map(" + g.gen.String() + ", ...)"
}

func (g *mappedGen) value(t *T) any {
	return g.fn(g.gen.value(t))
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

type sampledGen struct {
	slice []any
}

func (g *sampledGen) String() string {
	if len(g.slice) == 1 {
		return "Just(...)"
	}
	return "SampledFrom(...)"
}

func (g *sampledGen) value(t *T) any {
	i := genIndex(t.s, len(g.slice), true)
	return g.slice[i]
}

// OneOf randomly selects one of the provided generators.
// Equivalent to rapid.OneOf.
func OneOf(gens ...*Generator) *Generator {
	assertf(len(gens) > 0, "OneOf: at least one generator required")

	return newGenerator(&oneOfGen{
		gens: gens,
	})
}

type oneOfGen struct {
	gens []*Generator
}

func (g *oneOfGen) String() string {
	return "OneOf(...)"
}

func (g *oneOfGen) value(t *T) any {
	i := genIndex(t.s, len(g.gens), true)
	return g.gens[i].value(t)
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

type filteredGen struct {
	gen       *Generator
	predicate func(any) bool
}

func (g *filteredGen) String() string {
	return g.gen.String() + ".Filter(...)"
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

// find repeatedly tries to generate a value until success or maxTries.
// Discards failed attempts in the bitstream.
func find(genFn func(*T) (any, bool), t *T, maxTries int) any {
	// Use at least 100 tries for Filter operations
	if maxTries < 100 {
		maxTries = 100
	}

	for n := 0; n < maxTries; n++ {
		i := t.s.beginGroup(tryLabel, false)
		v, ok := genFn(t)
		t.s.endGroup(i, !ok)

		if ok {
			return v
		}
	}

	panic(invalidData("find: failed to generate value after max tries"))
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

type customGen struct {
	fn func(*T) any
}

func (g *customGen) String() string {
	return "Custom(...)"
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

type deferredGen struct {
	gen *Generator
	fn  func() *Generator
}

func (g *deferredGen) String() string {
	return "Deferred(...)"
}

func (g *deferredGen) value(t *T) any {
	if g.gen == nil {
		g.gen = g.fn()
	}
	return g.gen.value(t)
}

// Permutation creates a generator producing permutations of a slice.
// Equivalent to rapid.Permutation.
func Permutation(slice []any) *Generator {
	return newGenerator(&permGen{
		slice: slice,
	})
}

type permGen struct {
	slice []any
}

func (g *permGen) String() string {
	return "Permutation(...)"
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
