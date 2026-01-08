package staker

import (
	"strconv"
	"strings"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// UintTree is a wrapper around an AVL tree for storing block timestamps as strings.
// Since block timestamps are defined as int64, we take int64 and convert it to uint64 for the tree.
//
// Methods:
// - Get: Retrieves a value associated with a uint64 key.
// - set: Stores a value with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - remove: Removes a uint64 key and its associated value.
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

func (self *UintTree) Get(key int64) (any, bool) {
	v, ok := self.tree.Get(EncodeInt64(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key int64, value any) {
	self.tree.Set(EncodeInt64(key), value)
}

func (self *UintTree) Has(key int64) bool {
	return self.tree.Has(EncodeInt64(key))
}

func (self *UintTree) Remove(key int64) {
	self.tree.Remove(EncodeInt64(key))
}

func (self *UintTree) Iterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.Iterate(EncodeInt64(start), EncodeInt64(end), func(key string, value any) bool {
		return fn(DecodeInt64(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.ReverseIterate(EncodeInt64(start), EncodeInt64(end), func(key string, value any) bool {
		return fn(DecodeInt64(key), value)
	})
}

// Clone returns a deep copy of the UintTree.
func (self *UintTree) Clone() *UintTree {
	if self == nil {
		return nil
	}

	cloned := NewUintTree()
	self.tree.Iterate("", "", func(key string, value any) bool {
		cloned.tree.Set(key, cloneUintTreeValue(value))
		return false
	})

	return cloned
}

func cloneUintTreeValue(value any) any {
	switch v := value.(type) {
	case *u256.Uint:
		return v.Clone()
	case *avl.Tree:
		return cloneAvlTree(v)
	case []string:
		copied := make([]string, len(v))
		copy(copied, v)
		return copied
	case int64, int32, uint64, bool, string:
		return v
	default:
		return value
	}
}

func cloneAvlTree(tree *avl.Tree) *avl.Tree {
	if tree == nil {
		return nil
	}

	cloned := avl.NewTree()
	tree.Iterate("", "", func(key string, value any) bool {
		cloned.Set(key, cloneAvlTreeValue(value))
		return false
	})

	return cloned
}

func cloneAvlTreeValue(value any) any {
	switch v := value.(type) {
	case []string:
		copied := make([]string, len(v))
		copy(copied, v)
		return copied
	case *u256.Uint:
		return v.Clone()
	case int64, int32, uint64, bool, string:
		return v
	default:
		return value
	}
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

func EncodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return EncodeUint(uint64(num))
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

func DecodeInt64(s string) int64 {
	num, err := strconv.ParseInt(s, 10, 64)
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
