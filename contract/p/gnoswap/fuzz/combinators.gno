// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"math"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
)

const tryLabel = "try"

// Custom creates a generator which produces results of calling fn.
type customGen struct {
	fn func(bitStream) any
}

// String returns the display name of the custom generator.
//
// Returns:
//   - string: The name "Custom", used to identify this generator in draw groups and logs.
func (g *customGen) String() string {
	return "Custom"
}

func (g *customGen) value(t *T) any {
	return find(g.maybeValue, t, small)
}

func (g *customGen) maybeValue(t *T) (any, bool) {
	defer func() {
		if r := recover(); r != nil {
			if _, ok := r.(invalidData); !ok {
				panic(r)
			}
		}
	}()

	return g.fn(t.s), true
}

// Custom creates a generator which produces results of calling fn. Its callback
// takes the package-private bitStream type, so external callers should prefer
// Map, OneOf, or another public combinator.
//
// Parameters:
//   - fn: Callback that receives the generator's bit stream and returns one generated value; an invalidData panic requests a retry.
//
// Returns:
//   - *Generator: A generator that invokes fn and retries invalid-data attempts.
func Custom(fn func(bitStream) any) *Generator {
	return newGenerator(&customGen{
		fn: fn,
	})
}

// find attempts to generate a suitable value by retrying the generator function
//
// Parameters:
//   - gen: Callback for one generation attempt; it returns a candidate value and whether that value is usable.
//   - t: Test state passed to each generation attempt.
//   - tries: Maximum number of attempts before invalidData is raised.
//
// Returns:
//   - any: The first candidate accepted by gen; panics with invalidData when every attempt is rejected.
func find(gen func(*T) (any, bool), t *T, tries int) any {
	for n := 0; n < tries; n++ {
		i := t.s.beginGroup(tryLabel, false)
		v, ok := gen(t)
		t.s.endGroup(i, !ok)
		if ok {
			return v
		}
	}

	panic(invalidData(ufmt.Sprintf("failed to find suitable value in %d tries", tries)))
}

// Deferred creates a generator which defers calling fn until attempting to produce a value.
type deferredGen struct {
	g  *Generator
	fn func() *Generator
}

// String returns the display name of the deferred generator.
//
// Returns:
//   - string: The name "Deferred", used to identify this generator in draw groups and logs.
func (g *deferredGen) String() string {
	return "Deferred"
}

func (g *deferredGen) value(t *T) any {
	if g.g == nil {
		g.g = g.fn()
	}
	return g.g.value(t)
}

// Deferred creates a generator which defers calling fn until attempting to produce a value.
//
// Parameters:
//   - fn: Callback invoked lazily on the first generation attempt to construct the underlying generator.
//
// Returns:
//   - *Generator: A generator that postpones fn until a value is requested.
func Deferred(fn func() *Generator) *Generator {
	return newGenerator(&deferredGen{
		fn: fn,
	})
}

// Map creates a generator producing fn(u) for each u produced by g.
type mappedGen struct {
	g  *Generator
	fn func(any) any
}

// String returns the display name of the mapped generator, including its source generator.
//
// Returns:
//   - string: A "Map(...)" description identifying the source generator.
func (g *mappedGen) String() string {
	return ufmt.Sprintf("Map(%v, ...)", g.g)
}

func (g *mappedGen) value(t *T) any {
	return g.fn(g.g.value(t))
}

// Map creates a generator producing fn(u) for each u produced by g.
//
// Parameters:
//   - g: Source generator whose values are passed to fn.
//   - fn: Callback that transforms each value produced by g.
//
// Returns:
//   - *Generator: A generator that applies fn to every value drawn from g.
func Map(g *Generator, fn func(any) any) *Generator {
	return newGenerator(&mappedGen{
		g:  g,
		fn: fn,
	})
}

// Just creates a generator which always produces the given value.
//
// Parameters:
//   - val: Value that the returned generator must produce on every draw.
//
// Returns:
//   - *Generator: A singleton generator that always returns val.
func Just(val any) *Generator {
	return SampledFrom([]any{val})
}

// SampledFrom creates a generator which produces values from the given slice.
type sampledGen struct {
	slice []any
}

// String returns a description of the sampled generator and its candidate count.
//
// Returns:
//   - string: "Just(...)" for one candidate, or "SampledFrom(n items)" for multiple candidates.
func (g *sampledGen) String() string {
	if len(g.slice) == 1 {
		return ufmt.Sprintf("Just(%v)", g.slice[0])
	}
	return ufmt.Sprintf("SampledFrom(%v items)", len(g.slice))
}

func (g *sampledGen) value(t *T) any {
	i := genIndex(t.s, len(g.slice), true)
	return g.slice[i]
}

// SampledFrom creates a generator which produces values from the given slice.
//
// Parameters:
//   - slice: Non-empty set of candidate values from which each draw selects one element; an empty slice causes an assertion panic.
//
// Returns:
//   - *Generator: A generator that samples one value from slice on each draw.
func SampledFrom(slice []any) *Generator {
	assertf(len(slice) > 0, "slice should not be empty")

	return newGenerator(&sampledGen{
		slice: slice,
	})
}

// Permutation creates a generator which produces permutations of the given slice.
type permGen struct {
	slice []any
}

// String returns a description of the permutation generator and its item count.
//
// Returns:
//   - string: A "Permutation(n items)" description for the generator.
func (g *permGen) String() string {
	return ufmt.Sprintf("Permutation(%v items)", len(g.slice))
}

func (g *permGen) value(t *T) any {
	result := make([]any, len(g.slice))
	copy(result, g.slice)

	n := len(result)
	m := n - 1
	if m < 0 {
		m = 0
	}

	// shrink-friendly variant of Fisher–Yates shuffle
	repeat := newRepeat(0, m, math.MaxInt, "permute")
	for i := 0; repeat.more(t.s); i++ {
		j, _, _ := genUintRange(t.s, uint64(i), uint64(n-1), false)
		result[i], result[j] = result[j], result[i]
	}

	return result
}

// Permutation creates a generator which produces permutations of the given slice.
//
// Parameters:
//   - slice: Values to include in each generated permutation; duplicates and an empty slice are preserved.
//
// Returns:
//   - *Generator: A generator that produces a shuffled copy of slice on each draw.
func Permutation(slice []any) *Generator {
	return newGenerator(&permGen{
		slice: slice,
	})
}

// OneOf creates a generator which produces each value by selecting one of gens.
type oneOfGen struct {
	gens []*Generator
}

// String returns a description containing the selected generators' names.
//
// Returns:
//   - string: A "OneOf(...)" description listing the configured generator descriptions.
func (g *oneOfGen) String() string {
	strs := make([]string, len(g.gens))
	for i, gen := range g.gens {
		strs[i] = gen.String()
	}
	return ufmt.Sprintf("OneOf(%v)", strings.Join(strs, ", "))
}

func (g *oneOfGen) value(t *T) any {
	i := genIndex(t.s, len(g.gens), true)
	return g.gens[i].value(t)
}

// OneOf creates a generator which produces each value by selecting one of gens.
//
// Parameters:
//   - gens: One or more generators eligible for selection; an empty list causes an assertion panic.
//
// Returns:
//   - *Generator: A generator that selects one of gens for each draw.
func OneOf(gens ...*Generator) *Generator {
	assertf(len(gens) > 0, "at least one generator should be specified")

	return newGenerator(&oneOfGen{
		gens: gens,
	})
}
