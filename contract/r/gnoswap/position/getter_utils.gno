package position

func clonePosition(position Position) Position {
	return Position{
		operator:                 position.operator,
		poolKey:                  position.poolKey,
		tickLower:                position.tickLower,
		tickUpper:                position.tickUpper,
		liquidity:                position.liquidity,
		feeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
		tokensOwed0:              position.tokensOwed0,
		tokensOwed1:              position.tokensOwed1,
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
