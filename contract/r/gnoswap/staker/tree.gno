package staker

import (
	"strconv"
	"strings"

	avl "gno.land/p/nt/avl/v0"
)

// UintTree is a wrapper around an AVL tree for storing uint64 keys as strings.
//
// Methods:
// - Get: Retrieves a value associated with a uint64 key.
// - Set: Stores a value with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - Remove: Removes a uint64 key and its associated value.
// - Iterate: Iterates over keys and values in a range.
// - ReverseIterate: Iterates in reverse order over keys and values in a range.
type UintTree struct {
	tree *avl.Tree // blockTimestamp -> any
}

// NewUintTree creates a new UintTree instance.
func NewUintTree() *UintTree {
	return &UintTree{
		tree: avl.NewTree(),
	}
}

func (self *UintTree) Get(key uint64) (any, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key uint64, value any) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *UintTree) Has(key uint64) bool {
	return self.tree.Has(EncodeUint(key))
}

func (self *UintTree) Remove(key uint64) {
	self.tree.Remove(EncodeUint(key))
}

func (self *UintTree) Iterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value any) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.tree.ReverseIterate(EncodeUint(start), EncodeUint(end), func(key string, value any) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) Size() int {
	return self.tree.Size()
}

func (self *UintTree) IterateByOffset(offset, count int, fn func(key uint64, value any) bool) {
	self.tree.IterateByOffset(offset, count, func(key string, value any) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) Clone() *UintTree {
	if self == nil {
		return nil
	}

	cloned := NewUintTree()
	self.tree.Iterate("", "", func(key string, value any) bool {
		cloned.tree.Set(key, value)
		return false
	})

	return cloned
}

// EncodeUint converts a uint64 number into a zero-padded 20-character string.
//
// Parameters:
// - num (uint64): The number to encode.
//
// Returns:
// - string: A zero-padded string representation of the number.
//
// Example:
// Input: 12345
// Output: "00000000000000012345"
func EncodeUint(num uint64) string {
	// Convert the value to a decimal string.
	s := strconv.FormatUint(num, 10)

	// Zero-pad to a total length of 20 characters.
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

// DecodeUint converts a zero-padded string back into a uint64 number.
//
// Parameters:
// - s (string): The zero-padded string.
//
// Returns:
// - uint64: The decoded number.
//
// Panics:
// - If the string cannot be parsed into a uint64.
//
// Example:
// Input: "00000000000000012345"
// Output: 12345
func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return num
}

// EncodeInt takes an int32 and returns a zero-padded decimal string
// with up to 10 digits for the absolute value.
// If the number is negative, the '-' sign comes first, followed by zeros, then digits.
func EncodeInt(num int32) string {
	// Convert the absolute value to a decimal string.
	absValue := int64(num)
	isNegative := false
	if num < 0 {
		isNegative = true
		absValue = -absValue // Safely negate into int64 to avoid overflow.
	}

	s := strconv.FormatInt(absValue, 10)

	// Zero-pad to a total of 10 digits for the absolute value.
	// (The '-' sign will be added later if needed.)
	zerosNeeded := 10 - len(s)
	if zerosNeeded < 0 {
		zerosNeeded = 0
	}

	padded := strings.Repeat("0", zerosNeeded) + s

	// If the original number was negative, prepend '-'.
	if isNegative {
		return "-" + padded
	}
	return padded
}
