package fuzzing

import "math"

// Collection generators: Slice, Map, Permutation

// sliceOfGen generates slices.
type sliceOfGen struct {
	elemGen *Generator
	minLen  int
	maxLen  int
}

func (g *sliceOfGen) String() string {
	if g.minLen == 0 && g.maxLen == math.MaxInt {
		return "SliceOf(" + g.elemGen.String() + ")"
	}
	return "SliceOfN(" + g.elemGen.String() + ", ...)"
}

func (g *sliceOfGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	slice := make([]any, n)
	for i := range slice {
		slice[i] = g.elemGen.value(t)
	}
	return slice
}

// SliceOf creates a slice generator.
func SliceOf(elemGen *Generator) *Generator {
	return newGenerator(&sliceOfGen{elemGen: elemGen, minLen: 0, maxLen: 100})
}

// SliceOfN creates a slice generator with length in [minLen, maxLen].
func SliceOfN(elemGen *Generator, minLen, maxLen int) *Generator {
	return newGenerator(&sliceOfGen{elemGen: elemGen, minLen: minLen, maxLen: maxLen})
}

// mapOfGen generates maps.
type mapOfGen struct {
	keyGen   *Generator
	valueGen *Generator
	minSize  int
	maxSize  int
}

func (g *mapOfGen) String() string {
	if g.minSize == 0 && g.maxSize == math.MaxInt {
		return "MapOf(" + g.keyGen.String() + ", " + g.valueGen.String() + ")"
	}
	return "MapOfN(" + g.keyGen.String() + ", " + g.valueGen.String() + ", ...)"
}

func (g *mapOfGen) value(t *T) any {
	n, _, _ := genIntRange(t.s, int64(g.minSize), int64(g.maxSize), true)
	m := make(map[any]any)
	for i := 0; i < int(n); i++ {
		key := g.keyGen.value(t)
		value := g.valueGen.value(t)
		m[key] = value
	}
	return m
}

// MapOf creates a map generator.
func MapOf(keyGen, valueGen *Generator) *Generator {
	return newGenerator(&mapOfGen{keyGen: keyGen, valueGen: valueGen, minSize: 0, maxSize: 100})
}

// MapOfN creates a map generator with size in [minSize, maxSize].
func MapOfN(keyGen, valueGen *Generator, minSize, maxSize int) *Generator {
	return newGenerator(&mapOfGen{keyGen: keyGen, valueGen: valueGen, minSize: minSize, maxSize: maxSize})
}

// sliceOfDistinctGen generates slices with distinct elements.
type sliceOfDistinctGen struct {
	elemGen *Generator
	keyFn   func(any) any
	minLen  int
	maxLen  int
}

func (g *sliceOfDistinctGen) String() string {
	if g.minLen == 0 && g.maxLen == math.MaxInt {
		return "SliceOfDistinct(" + g.elemGen.String() + ")"
	}
	return "SliceOfNDistinct(" + g.elemGen.String() + ", ...)"
}

func (g *sliceOfDistinctGen) value(t *T) any {
	targetLen, _, _ := genIntRange(t.s, int64(g.minLen), int64(g.maxLen), true)
	slice := make([]any, 0, targetLen)
	seen := make(map[any]bool)

	// Try to generate distinct elements
	// Use a reasonable upper bound to avoid infinite loops
	maxTries := int(targetLen) * 10
	if maxTries < 100 {
		maxTries = 100
	}

	for len(slice) < int(targetLen) && maxTries > 0 {
		maxTries--

		i := t.s.beginGroup("distinct_try", false)
		elem := g.elemGen.value(t)
		key := elem
		if g.keyFn != nil {
			key = g.keyFn(elem)
		}

		if !seen[key] {
			seen[key] = true
			slice = append(slice, elem)
			t.s.endGroup(i, false)
		} else {
			t.s.endGroup(i, true) // Discard duplicate
		}
	}

	return slice
}

// SliceOfDistinct creates a slice generator with distinct elements.
// Elements are compared using the keyFn (if nil, elements are compared directly).
func SliceOfDistinct(elemGen *Generator, keyFn func(any) any) *Generator {
	return newGenerator(&sliceOfDistinctGen{
		elemGen: elemGen,
		keyFn:   keyFn,
		minLen:  0,
		maxLen:  100,
	})
}

// SliceOfNDistinct creates a slice generator with distinct elements and length bounds.
func SliceOfNDistinct(elemGen *Generator, minLen, maxLen int, keyFn func(any) any) *Generator {
	return newGenerator(&sliceOfDistinctGen{
		elemGen: elemGen,
		keyFn:   keyFn,
		minLen:  minLen,
		maxLen:  maxLen,
	})
}
