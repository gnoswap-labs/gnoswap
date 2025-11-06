// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzzing

import (
	"fmt"
	"math"
	"strings"
)

const tryLabel = "try"

// Custom creates a generator which produces results of calling fn.
type customGen struct {
	fn func(bitStream) any
}

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

// Custom creates a generator which produces results of calling fn.
func Custom(fn func(bitStream) any) *Generator {
	return newGenerator(&customGen{
		fn: fn,
	})
}

// find attempts to generate a suitable value by retrying the generator function
func find(gen func(*T) (any, bool), t *T, tries int) any {
	for n := 0; n < tries; n++ {
		i := t.s.beginGroup(tryLabel, false)
		v, ok := gen(t)
		t.s.endGroup(i, !ok)
		if ok {
			return v
		}
	}

	panic(invalidData(fmt.Sprintf("failed to find suitable value in %d tries", tries)))
}

// Deferred creates a generator which defers calling fn until attempting to produce a value.
type deferredGen struct {
	g  *Generator
	fn func() *Generator
}

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

func (g *mappedGen) String() string {
	return fmt.Sprintf("Map(%v, ...)", g.g)
}

func (g *mappedGen) value(t *T) any {
	return g.fn(g.g.value(t))
}

// Map creates a generator producing fn(u) for each u produced by g.
func Map(g *Generator, fn func(any) any) *Generator {
	return newGenerator(&mappedGen{
		g:  g,
		fn: fn,
	})
}

// Just creates a generator which always produces the given value.
func Just(val any) *Generator {
	return SampledFrom([]any{val})
}

// SampledFrom creates a generator which produces values from the given slice.
type sampledGen struct {
	slice []any
}

func (g *sampledGen) String() string {
	if len(g.slice) == 1 {
		return fmt.Sprintf("Just(%v)", g.slice[0])
	}
	return fmt.Sprintf("SampledFrom(%v items)", len(g.slice))
}

func (g *sampledGen) value(t *T) any {
	i := genIndex(t.s, len(g.slice), true)
	return g.slice[i]
}

// SampledFrom creates a generator which produces values from the given slice.
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

func (g *permGen) String() string {
	return fmt.Sprintf("Permutation(%v items)", len(g.slice))
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
func Permutation(slice []any) *Generator {
	return newGenerator(&permGen{
		slice: slice,
	})
}

// OneOf creates a generator which produces each value by selecting one of gens.
type oneOfGen struct {
	gens []*Generator
}

func (g *oneOfGen) String() string {
	strs := make([]string, len(g.gens))
	for i, gen := range g.gens {
		strs[i] = gen.String()
	}
	return fmt.Sprintf("OneOf(%v)", strings.Join(strs, ", "))
}

func (g *oneOfGen) value(t *T) any {
	i := genIndex(t.s, len(g.gens), true)
	return g.gens[i].value(t)
}

// OneOf creates a generator which produces each value by selecting one of gens.
func OneOf(gens ...*Generator) *Generator {
	assertf(len(gens) > 0, "at least one generator should be specified")

	return newGenerator(&oneOfGen{
		gens: gens,
	})
}

