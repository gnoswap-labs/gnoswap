package uinttree

import (
	"testing"
)

func TestUintTreeSetAndGetByInt64(t *testing.T) {
	tree := NewUintTree()
	tree.SetByInt64(7, "value")

	value, ok := tree.GetByInt64(7)
	if !ok {
		t.Fatal("expected key to exist")
	}
	if value != "value" {
		t.Fatalf("expected value, got %v", value)
	}
}

func TestUintTreeReverseIterateByInt64(t *testing.T) {
	tree := NewUintTree()
	tree.SetByInt64(5, "five")
	tree.SetByInt64(10, "ten")

	var latest string
	tree.ReverseIterateByInt64(0, 10, func(_ uint64, value any) bool {
		latest = value.(string)
		return true
	})

	if latest != "ten" {
		t.Fatalf("expected ten, got %s", latest)
	}
}

func TestUintTreeSetByInt64PanicsOnNegativeKey(t *testing.T) {
	tree := NewUintTree()

	defer func() {
		r := recover()
		if r == nil {
			t.Fatal("expected panic")
		}
		if r != "value must be non-negative" {
			t.Fatalf("unexpected panic: %v", r)
		}
	}()

	tree.SetByInt64(-1, "value")
}
