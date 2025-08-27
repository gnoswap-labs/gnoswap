package staker

import (
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// GetTotalxGnsSupply returns the total amount of xGNS supply.
func GetTotalxGnsSupply() int64 {
	return xgns.TotalSupply()
}

// GetTotalVoteWeight returns the total amount of xGNS used for voting.
func GetTotalVoteWeight() int64 {
	return xgns.VotingSupply()
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func GetTotalDelegated() int64 {
	return totalDelegatedAmount
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func GetTotalLockedAmount() int64 {
	return totalLockedAmount
}
