package staker

import (
	s "gno.land/r/position"
)

func NFTPositionInfoGetPositionInfo(tokenId string) (tickLower, tickUpper, liquidity bigint) {
	// liqPos := s.PositionGetPosition(tokenId)
	// return liqPos.tickLower, liqPos.tickUpper, liqPos.liquidity

	return s.PositionGetPositionTickLower(tokenId), s.PositionGetPositionTickUpper(tokenId), s.PositionGetPositionTickLiquidity(tokenId)
}
