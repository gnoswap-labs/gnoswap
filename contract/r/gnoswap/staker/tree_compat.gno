package staker

import (
	"strconv"
	"strings"

	utree "gno.land/p/gnoswap/uinttree"
)

type UintTree = utree.UintTree

func NewUintTree() *utree.UintTree {
	return utree.NewUintTree()
}

func EncodeUint(num uint64) string {
	return utree.EncodeUint(num)
}

func DecodeUint(s string) uint64 {
	return utree.DecodeUint(s)
}

// EncodeInt takes an int32 and returns a zero-padded decimal string
// with up to 10 digits for the absolute value.
func EncodeInt(num int32) string {
	absValue := int64(num)
	isNegative := false
	if num < 0 {
		isNegative = true
		absValue = -absValue
	}

	s := strconv.FormatInt(absValue, 10)
	zerosNeeded := 10 - len(s)
	if zerosNeeded < 0 {
		zerosNeeded = 0
	}

	padded := strings.Repeat("0", zerosNeeded) + s
	if isNegative {
		return "-" + padded
	}
	return padded
}
