package fuzz

import (
	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
)

// positionCollectFeeParams is the parameters for CollectFee fuzzing test
type positionCollectFeeParams struct {
	positionId    uint64
	unwrapResult  bool
}

func (p *positionCollectFeeParams) IsValid() bool {
	// Position ID must be non-zero
	if p.positionId == 0 {
		return false
	}

	return true
}

func (p *positionCollectFeeParams) ToString() string {
	return ufmt.Sprintf("positionId: %d, unwrapResult: %t",
		p.positionId,
		p.unwrapResult,
	)
}

func NewValidPositionCollectFeeParams(t *fuzz.T, existingPositionId uint64) *positionCollectFeeParams {
	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)

	return &positionCollectFeeParams{
		positionId:   existingPositionId,
		unwrapResult: unwrapResult,
	}
}

func NewRandomizedPositionCollectFeeParams(t *fuzz.T, existingPositionId uint64) *positionCollectFeeParams {
	unwrapResult := fuzz.Bool().Draw(t, "unwrapResult").(bool)

	return &positionCollectFeeParams{
		positionId:   existingPositionId,
		unwrapResult: unwrapResult,
	}
}
