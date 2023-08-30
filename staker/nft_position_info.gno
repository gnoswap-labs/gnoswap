package staker

import (
	s "gno.land/r/position"
)

func NFTPositionInfoGetPositionInfo(tokenId bigint) (tickLower, tickUpper, liquidity bigint) {
	return s.PositionGetPositionTickLower(tokenId), s.PositionGetPositionTickUpper(tokenId), s.PositionGetPositionTickLiquidity(tokenId)
}
