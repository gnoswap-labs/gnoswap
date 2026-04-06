package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestUintTreeSetAndGetByInt64(t *testing.T) {
	tree := NewUintTree()
	tree.SetByInt64(7, "value")

	value, ok := tree.GetByInt64(7)
	uassert.True(t, ok)
	uassert.Equal(t, "value", value)
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

	uassert.Equal(t, "ten", latest)
}

func TestUintTreeSetByInt64PanicsOnNegativeKey(t *testing.T) {
	tree := NewUintTree()

	defer func() {
		r := recover()
		uassert.NotEqual(t, nil, r)
		uassert.Equal(t, "value must be non-negative", r)
	}()

	tree.SetByInt64(-1, "value")
}
