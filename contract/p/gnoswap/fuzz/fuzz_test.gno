package fuzz

import (
	"math"
	"strconv"
	"strings"
	"testing"
)

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

func TestGenerateBoundaryValues_Int(t *testing.T) {
	values := GenerateBoundary("int")
	expected := map[any]bool{
		0: true, 1: true, -1: true,
		int(math.MaxInt): true, int(math.MinInt): true,
		int(math.MaxInt - 1): true, int(math.MinInt + 1): true,
	}

	for _, v := range values {
		if _, ok := expected[v]; !ok {
			t.Errorf("Unexpected value: %v", v)
		}
		delete(expected, v)
	}
	for missing := range expected {
		t.Errorf("Missing value: %v", missing)
	}
}

func TestGenerateBoundaryValues_Uint(t *testing.T) {
	values := GenerateBoundary("uint")
	expected := map[any]bool{
		uint(0): true, uint(1): true,
		uint(math.MaxUint): true, uint(math.MaxUint - 1): true,
	}

	for _, v := range values {
		if _, ok := expected[v]; !ok {
			t.Errorf("Unexpected value: %v", v)
		}
		delete(expected, v)
	}
	for missing := range expected {
		t.Errorf("Missing value: %v", missing)
	}
}

func TestGenerateBoundaryValues_String(t *testing.T) {
	values := GenerateBoundary("string")
	if len(values) == 0 {
		t.Errorf("Expected some values but got none")
	}
	for _, v := range values {
		if _, ok := v.(string); !ok {
			t.Errorf("Expected string value but got %T", v)
		}
	}
}

func TestGenerateBoundaryValues_Slice(t *testing.T) {
	values := GenerateBoundary("slice")
	if len(values) == 0 {
		t.Errorf("Expected some values but got none")
	}
	for _, v := range values {
		if _, ok := v.([]int); !ok {
			t.Errorf("Expected []int value but got %T", v)
		}
	}
}

func TestGenerateBoundaryValues_UnknownType(t *testing.T) {
	values := GenerateBoundary("invalid-type")
	if len(values) != 0 {
		t.Errorf("Expected no values but got %v", values)
	}
}

func TestNumberStringGenerator(t *testing.T) {
	gen := NumberString()

	for i := 0; i < 100; i++ {
		value := gen.Generate().(string)

		if strings.HasPrefix(value, "0b") {
			binary := strings.TrimPrefix(value, "0b")
			if _, err := strconv.ParseInt(binary, 2, 64); err != nil {
				t.Errorf("Invalid binary string: %s", value)
			}
		} else if strings.HasPrefix(value, "0o") {
			octal := strings.TrimPrefix(value, "0o")
			if _, err := strconv.ParseInt(octal, 8, 64); err != nil {
				t.Errorf("Invalid octal string: %s", value)
			}
		} else if strings.HasPrefix(value, "0x") {
			hex := strings.TrimPrefix(value, "0x")
			if _, err := strconv.ParseInt(hex, 16, 64); err != nil {
				t.Errorf("Invalid hex string: %s", value)
			}
		} else {
			if _, err := strconv.ParseInt(value, 10, 64); err != nil {
				t.Errorf("Invalid decimal string: %s", value)
			}
		}
	}
}

func TestNumberStringGeneratorWithRange(t *testing.T) {
	gen := NumberStringRange(-100, 100, 10, 16)

	for i := 0; i < 50; i++ {
		value := gen.Generate().(string)

		var parsed int64
		var err error

		if strings.HasPrefix(value, "0x") {
			hex := strings.TrimPrefix(value, "0x")
			parsed, err = strconv.ParseInt(hex, 16, 64)
		} else {
			parsed, err = strconv.ParseInt(value, 10, 64)
		}

		if err != nil {
			t.Errorf("Failed to parse number string: %s", value)
			continue
		}

		if parsed < -100 || parsed > 100 {
			t.Errorf("Value out of range: %d from %s", parsed, value)
		}
	}
}

func TestGenerateBoundaryValues_NumberString(t *testing.T) {
	values := GenerateBoundary("numberString")

	if len(values) == 0 {
		t.Errorf("Expected boundary values for numberString")
		return
	}

	expectedPatterns := []string{
		"0", "1", "-1",
		"0b", "0o", "0x",
	}

	foundPatterns := make(map[string]bool)
	for _, v := range values {
		s, ok := v.(string)
		if !ok {
			t.Errorf("Expected string value but got %T", v)
			continue
		}

		for _, pattern := range expectedPatterns {
			if strings.HasPrefix(s, pattern) || s == pattern {
				foundPatterns[pattern] = true
			}
		}
	}

	for _, pattern := range expectedPatterns[:3] {
		if !foundPatterns[pattern] {
			t.Errorf("Missing boundary value pattern: %s", pattern)
		}
	}
}
