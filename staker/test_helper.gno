package staker

import (
	"testing"
)


func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}