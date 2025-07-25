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
