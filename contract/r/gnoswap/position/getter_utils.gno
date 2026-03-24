package position

func clonePosition(position Position) Position {
	return Position{
		operator:                 position.operator,
		poolKey:                  position.poolKey,
		tickLower:                position.tickLower,
		tickUpper:                position.tickUpper,
		liquidity:                position.liquidity.Clone(),
		feeGrowthInside0LastX128: position.feeGrowthInside0LastX128.Clone(),
		feeGrowthInside1LastX128: position.feeGrowthInside1LastX128.Clone(),
		tokensOwed0:              position.tokensOwed0.Clone(),
		tokensOwed1:              position.tokensOwed1.Clone(),
		burned:                   position.burned,
	}
}

func cloneUint64Slice(src []uint64) []uint64 {
	if src == nil {
		return nil
	}

	dst := make([]uint64, len(src))
	copy(dst, src)
	return dst
}
