package governance

import (
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerAccessor struct{}

// GetTotalDelegationAmountAtSnapshot forwards an aggregate delegation-history lookup.
//
// Parameters:
//   - snapshotTime: Unix timestamp at or before which to select the latest total-delegation entry.
//
// Returns:
//   - int64: aggregate delegated amount at or before snapshotTime.
//   - bool: true when a qualifying history entry exists; false otherwise.
func (g *govStakerAccessor) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return staker.GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

// GetUserDelegationAmountAtSnapshot forwards a user's delegation-history lookup.
//
// Parameters:
//   - userAddr: Delegator address whose historical amount is queried.
//   - snapshotTime: Unix timestamp at or before which to select the latest user entry.
//
// Returns:
//   - int64: user's delegated amount at or before snapshotTime.
//   - bool: true when a qualifying history entry exists; false otherwise.
func (g *govStakerAccessor) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return staker.GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

// GetTotalxGnsSupply returns the total xGNS supply reported by the staker realm.
//
// Returns:
//   - int64: total xGNS supply, including launchpad-held xGNS.
func (g *govStakerAccessor) GetTotalxGnsSupply() int64 {
	return staker.GetTotalxGnsSupply()
}

func newGovStakerAccessor() GovStakerAccessor {
	return &govStakerAccessor{}
}
