package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// positionCollectFeeParams is the parameters for CollectFee fuzzing test
type positionCollectFeeParams struct {
	positionId   uint64
	unwrapResult bool
	poolPath     string
}

func (p *positionCollectFeeParams) IsValid() bool {
	if p.positionId == 0 {
		return false
	}

	_, err := position.GetPosition(p.positionId)
	if err != nil {
		return false
	}

	poolPath := position.GetPositionPoolKey(p.positionId)
	if poolPath == "" {
		return false
	}

	if !pool.ExistsPoolPath(poolPath) {
		return false
	}

	return true
}

func (p *positionCollectFeeParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, unwrapResult: %t, poolPath: %s",
		p.positionId,
		p.unwrapResult,
		p.poolPath,
	)
}

func NewValidPositionCollectFeeParams(t *fuzz.T, existingPositionId uint64) *positionCollectFeeParams {
	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)
	return newExistingPositionCollectFeeParams(existingPositionId, unwrapResult)
}

func NewRandomizedPositionCollectFeeParams(t *fuzz.T, existingPositionId uint64) *positionCollectFeeParams {
	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)

	scenario := fuzz.IntRange(0, 2).Draw(t, "collectFeeScenario").(int)
	switch scenario {
	case 0:
		return newExistingPositionCollectFeeParams(existingPositionId, unwrapResult)
	case 1:
		offset := fuzz.Int64Range(1, 1024).Draw(t, "positionOffset").(int64)
		if offset < 0 {
			offset = -offset
		}
		randomPositionId := existingPositionId + uint64(offset)
		if randomPositionId < existingPositionId {
			randomPositionId = existingPositionId
		}

		return &positionCollectFeeParams{
			positionId:   randomPositionId,
			unwrapResult: unwrapResult,
			poolPath:     randomPoolPath(t),
		}
	default:
		return &positionCollectFeeParams{
			positionId:   0,
			unwrapResult: unwrapResult,
			poolPath:     "",
		}
	}
}

func newExistingPositionCollectFeeParams(positionId uint64, unwrapResult bool) *positionCollectFeeParams {
	poolPath := position.GetPositionPoolKey(positionId)
	return &positionCollectFeeParams{
		positionId:   positionId,
		unwrapResult: unwrapResult,
		poolPath:     poolPath,
	}
}

func randomPoolPath(t *fuzz.T) string {
	token0Path, token1Path := generateTokenPair(t)
	fee := generateFeeTier(t)
	return pool.GetPoolPath(token0Path, token1Path, fee)
}
