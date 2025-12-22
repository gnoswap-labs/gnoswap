package governance

import (
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerAccessor struct{}

func (g *govStakerAccessor) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return staker.GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

func (g *govStakerAccessor) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return staker.GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

func newGovStakerAccessor() GovStakerAccessor {
	return &govStakerAccessor{}
}
