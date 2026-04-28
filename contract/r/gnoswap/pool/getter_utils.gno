package pool

import (
	"time"

	bptree "gno.land/p/nt/bptree/v0"
)

func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	cloned := make([]string, len(src))
	copy(cloned, src)
	return cloned
}

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

func clonePositionInfo(src PositionInfo) PositionInfo {
	return PositionInfo{
		liquidity:                src.liquidity,
		feeGrowthInside0LastX128: src.feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: src.feeGrowthInside1LastX128,
		tokensOwed0:              src.tokensOwed0,
		tokensOwed1:              src.tokensOwed1,
	}
}

func cloneObservationState(src *ObservationState) *ObservationState {
	if src == nil {
		return nil
	}

	observations := make(map[uint16]*Observation)
	for index, observation := range src.observations {
		observations[index] = observation.Clone()
	}

	return &ObservationState{
		observations:    observations,
		index:           src.index,
		cardinality:     src.cardinality,
		cardinalityNext: src.cardinalityNext,
	}
}

func clonePool(src *Pool) *Pool {
	if src == nil {
		return nil
	}

	return &Pool{
		token0Path:  src.token0Path,
		token1Path:  src.token1Path,
		fee:         src.fee,
		tickSpacing: src.tickSpacing,
		slot0: Slot0{
			sqrtPriceX96: src.slot0.sqrtPriceX96.Clone(),
			tick:         src.slot0.tick,
			feeProtocol:  src.slot0.feeProtocol,
			unlocked:     src.slot0.unlocked,
		},
		balances:             src.balances,
		protocolFees:         src.protocolFees,
		feeGrowthGlobal0X128: src.feeGrowthGlobal0X128.Clone(),
		feeGrowthGlobal1X128: src.feeGrowthGlobal1X128.Clone(),
		liquidity:            src.liquidity.Clone(),
		ticks:                bptree.NewBPTreeN(16),
		tickBitmaps:          make(map[int16]string),
		positions:            bptree.NewBPTreeN(16),
		observationState:     NewObservationState(time.Now().Unix()),
	}
}

func clonePoolTicks(src *bptree.BPTree) *bptree.BPTree {
	if src == nil {
		return bptree.NewBPTreeN(16)
	}

	cloned := bptree.NewBPTreeN(16)

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

func NewDefaultPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                "0",
		feeGrowthInside0LastX128: "0",
		feeGrowthInside1LastX128: "0",
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
}
