package fuzztest

import (
	"errors"

	xs "gno.land/p/wyhaines/rand/xorshift64star"
)

type Generator interface {
	Generate() any
}

func initRNG(rng **xs.Xorshift64Star) {
	if *rng == nil {
		*rng = xs.New()
	}
}

// TODO: add more generators
var (
	_ Generator = (*IntGenerator)(nil)
	_ Generator = (*Uint32Generator)(nil)
)

type IntGenerator struct {
	min, max int
	rng      *xs.Xorshift64Star
}

func (g *IntGenerator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return int(int32(g.rng.Uint64()))
	}
	size := uint64(g.max - g.min + 1)
	return int(g.rng.Uint64()%size) + g.min
}

func IntRange(min, max int) Generator {
	return &IntGenerator{
		min: min,
		max: max,
		rng: xs.New(),
	}
}

type Uint32Generator struct {
	min, max uint32
	rng      *xs.Xorshift64Star
}

func (g *Uint32Generator) Generate() any {
	initRNG(&g.rng)
	if g.min == 0 && g.max == 0 {
		return uint32(g.rng.Uint64())
	}
	size := uint64(g.max - g.min + 1)
	return uint32(g.rng.Uint64()%size) + g.min
}

func Uint32Range(min, max uint32) Generator {
	return &Uint32Generator{
		min: min,
		max: max,
		rng: xs.New(),
	}
}

func Uint32() Generator {
	return Uint32Range(0, 100)
}

type BoolGenerator struct {
	rng *xs.Xorshift64Star
}

func (g *BoolGenerator) Generate() any {
	initRNG(&g.rng)
	return g.rng.Uint64()%2 == 0
}

func Bool() Generator {
	return &BoolGenerator{rng: xs.New()}
}

type StringGenerator struct {
	minLen, maxLen int
	rng            *xs.Xorshift64Star
}

func (g *StringGenerator) Generate() interface{} {
	initRNG(&g.rng)
	if g.maxLen == 0 {
		g.maxLen = 10
	}
	lengthRange := uint64(g.maxLen - g.minLen + 1)
	length := int(g.rng.Uint64()%lengthRange) + g.minLen
	result := make([]byte, length)
	for i := range result {
		result[i] = byte(g.rng.Uint64()%94 + 33)
	}
	return string(result)
}

// Config controls fuzzing parameters
type Config struct {
	Iterations int
	Shrink     bool
}

type Result struct {
	Failed       bool
	FailingInput any
	Iterations   int
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func shrinkInt(property func(int) bool, failingInput int) int {
	current := failingInput
	for attempt := 0; attempt < 100; attempt++ {
		candidates := []int{0, 1, -1, current / 2, current - 1, current + 1}
		for _, candidate := range candidates {
			if !property(candidate) && abs(candidate) <= abs(current) {
				current = candidate
			}
		}
	}
	return current
}

func FuzzWithConfig(config Config, property func(int) bool) *Result {
	return FuzzWithConfigAndGen(config, &IntGenerator{rng: xs.New()}, property)
}

func FuzzWithConfigAndGen(config Config, gen Generator, property func(int) bool) *Result {
	result := &Result{}
	iterations := config.Iterations
	if iterations == 0 {
		iterations = 100
	}
	var failingInput int
	for i := 0; i < iterations; i++ {
		result.Iterations++
		value := gen.Generate().(int)
		if !property(value) {
			failingInput = value
			result.Failed = true
			break
		}
	}
	if !result.Failed {
		return result
	}
	if config.Shrink {
		result.FailingInput = shrinkInt(property, failingInput)
	} else {
		result.FailingInput = failingInput
	}
	return result
}

func Fuzz(property interface{}) error {
	if fn, ok := property.(func(int) bool); ok {
		return FuzzWithGen(IntRange(0, 1000), fn)
	}
	if fn, ok := property.(func(string) bool); ok {
		return fuzzString(fn)
	}
	return errors.New("unsupported property type")
}

func fuzzString(fn func(string) bool) error {
	gen := &StringGenerator{rng: xs.New()}
	for i := 0; i < 100; i++ {
		if !fn(gen.Generate().(string)) {
			return errors.New("property violation")
		}
	}
	return nil
}

func FuzzWithGen(gen Generator, property func(int) bool) error {
	for i := 0; i < 100; i++ {
		value := gen.Generate().(int)
		if !property(value) {
			return errors.New("property violation")
		}
	}
	return nil
}

func FuzzN(property interface{}) error {
	if fn, ok := property.(func(int, int) bool); ok {
		gen := &IntGenerator{rng: xs.New()}
		for i := 0; i < 100; i++ {
			a := gen.Generate().(int)
			b := gen.Generate().(int)
			if !fn(a, b) {
				return errors.New("property violation")
			}
		}
		return nil
	}
	return errors.New("unsupported property type")
}
