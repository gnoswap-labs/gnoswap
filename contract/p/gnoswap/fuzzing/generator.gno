package fuzzing

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

// find repeatedly tries to generate a value until success or maxTries.
// Discards failed attempts in the bitstream.
// This is used by Filter and Custom generators.
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
