package pool

import (
	bptree "gno.land/p/nt/bptree/v0"
)

func cloneInt32Slice(src []int32) []int32 {
	if src == nil {
		return nil
	}

	cloned := make([]int32, len(src))
	copy(cloned, src)
	return cloned
}

func cloneFeeAmountTickSpacings(src map[uint32]int32) map[uint32]int32 {
	if src == nil {
		return nil
	}

	cloned := make(map[uint32]int32, len(src))
	for fee, spacing := range src {
		cloned[fee] = spacing
	}

	return cloned
}

func clonePoolTicks(src *bptree.BPTree) *bptree.BPTree {
	if src == nil {
		return bptree.NewBPTreeN(32)
	}

	cloned := bptree.NewBPTreeN(32)

	src.Iterate("", "", func(key string, value any) bool {
		cloned.Set(key, value)
		return false
	})

	return cloned
}

func clonePoolTickBitmaps(src map[int16]string) map[int16]string {
	if src == nil {
		return make(map[int16]string)
	}

	cloned := make(map[int16]string, len(src))
	for wordPos, bitmap := range src {
		cloned[wordPos] = bitmap
	}

	return cloned
}

func cloneStringInt64Map(src map[string]int64) map[string]int64 {
	if src == nil {
		return nil
	}

	cloned := make(map[string]int64, len(src))
	for k, v := range src {
		cloned[k] = v
	}

	return cloned
}

func NewDefaultPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                "0",
		feeGrowthInside0LastX128: "0",
		feeGrowthInside1LastX128: "0",
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
}
