// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzzing

type generatorImpl interface {
	String() string
	value(t *T) any
}

// Generator describes a generator of values.
type Generator struct {
	impl generatorImpl
	str  string
}

func newGenerator(impl generatorImpl) *Generator {
	return &Generator{
		impl: impl,
		str:  impl.String(),
	}
}

func (g *Generator) String() string {
	return g.str
}

// Draw produces a value from the generator.
func (g *Generator) Draw(t *T, label string) any {
	v := g.value(t)

	if len(t.refDraws) > 0 && t.draws < len(t.refDraws) {
		ref := t.refDraws[t.draws]
		// In Gno we can't use reflect.DeepEqual, so we skip validation
		_ = ref
	}

	t.draws++
	return v
}

// value produces a value from the generator.
func (g *Generator) value(t *T) any {
	i := t.s.beginGroup(g.str, true)
	v := g.impl.value(t)
	t.s.endGroup(i, false)
	return v
}

// Example produces an example value from the generator.
func (g *Generator) Example(seed uint64) any {
	s := newRandomBitStream(seed, false)
	t := newT(s)
	v := g.value(t)
	return v
}

// Map creates a generator producing fn(v) for each v produced by g.
func (g *Generator) Map(fn func(any) any) *Generator {
	return Map(g, fn)
}
