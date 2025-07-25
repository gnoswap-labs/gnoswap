package fuzztest

import "testing"

type TestCase struct {
	orderId int
	amount  uint32
	express bool
	notes   string
}

func generateTestCase() TestCase {
	return TestCase{
		orderId: IntRange(-10, 1000).Generate().(int),
		amount:  Uint32Range(0, 500).Generate().(uint32),
		express: Bool().Generate().(bool),
		notes:   (&StringGenerator{minLen: 0, maxLen: 50}).Generate().(string),
	}
}

func validateOrder(orderId int, amount uint32, express bool, notes string) bool {
	if orderId <= 0 {
		return false
	}
	if amount == 0 {
		return false
	}
	if express && amount < 100 {
		return false
	}
	if len(notes) > 1000 {
		return false
	}
	return true
}

func TestComplexPropertyWithWrapper(t *testing.T) {
	const total = 100
	failures := 0

	for i := 0; i < total; i++ {
		tc := generateTestCase()
		result := validateOrder(tc.orderId, tc.amount, tc.express, tc.notes)

		if tc.orderId <= 0 && result {
			t.Errorf("Should fail for non-positive orderId: %+v", tc)
			failures++
		}
		if tc.amount == 0 && result {
			t.Errorf("Should fail for zero amount: %+v", tc)
			failures++
		}
		if tc.express && tc.amount < 100 && result {
			t.Errorf("Should fail for express with low amount: %+v", tc)
			failures++
		}
	}

	if failures > 0 {
		t.Logf("Total failures: %d out of %d", failures, total)
	}
}

func TestFuzzSingleIntParameter(t *testing.T) {
	double := func(x int) int {
		return x * 2
	}

	err := Fuzz(func(x int) bool {
		return double(x) == x*2
	})
	if err != nil {
		t.Errorf("property failed when it shouldn't: %v", err)
	}
}

func TestShouldDetectsViolation(t *testing.T) {
	failures := func(x int) int {
		if x < -100 {
			return x // <- bug: negative result
		}
		return abs(x)
	}

	err := FuzzWithGen(
		IntRange(-200, 200),
		func(x int) bool {
			return failures(x) >= 0
		},
	)

	if err == nil {
		t.Errorf("Expected property violation but none was detected")
	}
}

func TestFuzzWithMultipleParameters(t *testing.T) {
	add := func(a, b int) int {
		return a + b
	}

	err := FuzzN(func(a, b int) bool {
		return add(a, b) == add(b, a) // should be commutative
	})
	if err != nil {
		t.Errorf("property failed when it shouldn't: %v", err)
	}
}

func TestFuzzStringParameter(t *testing.T) {
	strLen := func(s string) int {
		return len(s)
	}

	err := Fuzz(func(s string) bool {
		return strLen(s) >= 0
	})
	if err != nil {
		t.Errorf("property failed when it shouldn't: %v", err)
	}
}

func TestCustomGenerator(t *testing.T) {
	isPositive := func(x int) bool {
		return x > 0
	}

	err := FuzzWithGen(
		IntRange(1, 1000),
		func(x int) bool {
			return isPositive(x)
		},
	)
	if err != nil {
		t.Errorf("property failed when it shouldn't: %v", err)
	}
}

func TestShrinking(t *testing.T) {
	failure := func(x int) bool {
		return x < 100
	}

	result := FuzzWithConfigAndGen(
		Config{Shrink: true, Iterations: 100},
		IntRange(0, 200),
		failure,
	)

	if !result.Failed {
		t.Errorf("Expected property violation but none was detected")
	}
	if result.FailingInput != 100 {
		t.Errorf("Expected failing input to be 100 but got %v", result.FailingInput)
	}
}
