package v1

import (
	"gno.land/r/gnoswap/gov/xgns"
)

// GetTotalxGnsSupply returns the total amount of xGNS supply.
func (gs *govStakerV1) GetTotalxGnsSupply() int64 {
	return xgns.TotalSupply()
}

// GetTotalVoteWeight returns the total amount of xGNS used for voting.
func (gs *govStakerV1) GetTotalVoteWeight() int64 {
	return xgns.VotingSupply()
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func (gs *govStakerV1) GetTotalDelegated() int64 {
	totalDelegatedAmount, err := gs.store.GetTotalDelegatedAmount()
	if err != nil {
		panic(err)
	}

	return totalDelegatedAmount
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func (gs *govStakerV1) GetTotalLockedAmount() int64 {
	totalLockedAmount, err := gs.store.GetTotalLockedAmount()
	if err != nil {
		panic(err)
	}

	return totalLockedAmount
}
