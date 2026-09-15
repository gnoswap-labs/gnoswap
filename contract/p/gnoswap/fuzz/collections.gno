// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import ufmt "gno.land/p/nt/ufmt/v0"

// SliceOfN creates a slice generator with min/max length constraints.
// If minLen >= 0, generated slices have minimum length of minLen.
// If maxLen >= 0, generated slices have maximum length of maxLen.
//
// Parameters:
//   - elem: Generator used to produce each slice element.
//   - minLen: Inclusive minimum slice length; a negative value leaves the lower bound unconstrained.
//   - maxLen: Inclusive maximum slice length; a negative value leaves the upper bound unconstrained.
//
// Returns:
//   - generator: Generator that produces slices of values from elem within the requested length bounds.
func SliceOfN(elem *Generator, minLen int, maxLen int) *Generator {
	assertValidRange(minLen, maxLen)

	return newGenerator(&sliceGen{
		minLen: minLen,
		maxLen: maxLen,
		elem:   elem,
	})
}

// SliceOf creates a slice generator with no length constraints.
//
// Parameters:
//   - elem: Generator used to produce each slice element.
//
// Returns:
//   - generator: Generator that produces slices with no configured length bounds.
func SliceOf(elem *Generator) *Generator {
	return SliceOfN(elem, -1, -1)
}

type sliceGen struct {
	minLen int
	maxLen int
	elem   *Generator
}

// String returns the configured slice generator in a readable form.
//
// Returns:
//   - text: Configuration text showing the element generator and any length bounds.
func (g *sliceGen) String() string {
	if g.minLen < 0 && g.maxLen < 0 {
		return ufmt.Sprintf("SliceOf(%v)", g.elem)
	}
	return ufmt.Sprintf("SliceOfN(%v, minLen=%v, maxLen=%v)", g.elem, g.minLen, g.maxLen)
}

// value generates one slice by repeatedly sampling the element generator.
//
// Parameters:
//   - t: Fuzzing context whose bit stream supplies the element values and repetition count.
//
// Returns:
//   - value: Generated slice containing values sampled from elem.
func (g *sliceGen) value(t *T) any {
	repeat := newRepeat(g.minLen, g.maxLen, -1, g.elem.String())

	sl := make([]any, 0, repeat.avg())
	for repeat.more(t.s) {
		e := g.elem.value(t)
		sl = append(sl, e)
	}

	return sl
}

// MapOfN creates a map generator with min/max length constraints.
// If minLen >= 0, generated maps have minimum length of minLen.
// If maxLen >= 0, generated maps have maximum length of maxLen.
//
// Parameters:
//   - key: Generator used to produce each map key.
//   - val: Generator used to produce the value paired with each key.
//   - minLen: Inclusive minimum map length; a negative value leaves the lower bound unconstrained.
//   - maxLen: Inclusive maximum map length; a negative value leaves the upper bound unconstrained.
//
// Returns:
//   - generator: Generator that produces maps with unique sampled keys within the requested length bounds.
func MapOfN(key *Generator, val *Generator, minLen int, maxLen int) *Generator {
	assertValidRange(minLen, maxLen)

	return newGenerator(&mapGen{
		minLen: minLen,
		maxLen: maxLen,
		key:    key,
		val:    val,
	})
}

// MapOf creates a map generator with no length constraints.
//
// Parameters:
//   - key: Generator used to produce each map key.
//   - val: Generator used to produce the value paired with each key.
//
// Returns:
//   - generator: Generator that produces maps with no configured length bounds.
func MapOf(key *Generator, val *Generator) *Generator {
	return MapOfN(key, val, -1, -1)
}

type mapGen struct {
	minLen int
	maxLen int
	key    *Generator
	val    *Generator
}

// String returns the configured map generator in a readable form.
//
// Returns:
//   - text: Configuration text showing the key/value generators and any length bounds.
func (g *mapGen) String() string {
	if g.minLen < 0 && g.maxLen < 0 {
		return ufmt.Sprintf("MapOf(%v, %v)", g.key, g.val)
	}
	return ufmt.Sprintf("MapOfN(%v, %v, minLen=%v, maxLen=%v)", g.key, g.val, g.minLen, g.maxLen)
}

// value generates one map by sampling key/value pairs until the repetition count is met; duplicate keys are rejected.
//
// Parameters:
//   - t: Fuzzing context whose bit stream supplies keys, values, and repetition decisions.
//
// Returns:
//   - value: Generated map containing unique keys and their sampled values.
func (g *mapGen) value(t *T) any {
	label := g.key.String() + "," + g.val.String()
	repeat := newRepeat(g.minLen, g.maxLen, -1, label)

	m := make(map[any]any, repeat.avg())
	for repeat.more(t.s) {
		k := g.key.value(t)
		v := g.val.value(t)

		if _, ok := m[k]; ok {
			repeat.reject()
		} else {
			m[k] = v
		}
	}

	return m
}

// assertValidRange verifies that a constrained range is ordered.
//
// Parameters:
//   - min: Requested lower bound; negative values represent an unconstrained lower bound.
//   - max: Requested upper bound; negative values represent an unconstrained upper bound.
//
// The function panics when max is constrained and min is greater than max.
func assertValidRange(min int, max int) {
	if max >= 0 && min > max {
		panic(ufmt.Sprintf("invalid range [%d, %d]", min, max))
	}
}
