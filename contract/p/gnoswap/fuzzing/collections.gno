// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzzing

import "fmt"

// SliceOfN creates a slice generator with min/max length constraints.
// If minLen >= 0, generated slices have minimum length of minLen.
// If maxLen >= 0, generated slices have maximum length of maxLen.
func SliceOfN(elem *Generator, minLen int, maxLen int) *Generator {
	assertValidRange(minLen, maxLen)

	return newGenerator(&sliceGen{
		minLen: minLen,
		maxLen: maxLen,
		elem:   elem,
	})
}

// SliceOf creates a slice generator with no length constraints.
func SliceOf(elem *Generator) *Generator {
	return SliceOfN(elem, -1, -1)
}

type sliceGen struct {
	minLen int
	maxLen int
	elem   *Generator
}

func (g *sliceGen) String() string {
	if g.minLen < 0 && g.maxLen < 0 {
		return fmt.Sprintf("SliceOf(%v)", g.elem)
	}
	return fmt.Sprintf("SliceOfN(%v, minLen=%v, maxLen=%v)", g.elem, g.minLen, g.maxLen)
}

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
func MapOf(key *Generator, val *Generator) *Generator {
	return MapOfN(key, val, -1, -1)
}

type mapGen struct {
	minLen int
	maxLen int
	key    *Generator
	val    *Generator
}

func (g *mapGen) String() string {
	if g.minLen < 0 && g.maxLen < 0 {
		return fmt.Sprintf("MapOf(%v, %v)", g.key, g.val)
	}
	return fmt.Sprintf("MapOfN(%v, %v, minLen=%v, maxLen=%v)", g.key, g.val, g.minLen, g.maxLen)
}

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

func assertValidRange(min int, max int) {
	if max >= 0 && min > max {
		panic(fmt.Sprintf("invalid range [%d, %d]", min, max))
	}
}
