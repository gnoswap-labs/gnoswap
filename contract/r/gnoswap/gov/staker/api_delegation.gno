package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/gns"
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
func GetTotalDelegated() uint64 {
	return delegationState.TotalDelegated()
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func GetTotalLockedAmount() uint64 {
	return lockedAmount
}

// GetTotalDelegatedFrom returns the total amount of xGNS delegated by given address.
func GetTotalDelegatedFrom(from std.Address) uint64 {
	amount, exist := delegationState.DelegatorAmount()[from.String()]
	if !exist {
		return 0
	}
	return amount
}

// GetTotalDelegatedTo returns the total amount of xGNS delegated to given address.
func GetTotalDelegatedTo(to std.Address) uint64 {
	amount, exist := delegationState.DelegatedTo()[to.String()]
	if !exist {
		return 0
	}
	return amount
}

// GetDelegationAmountFromTo returns the amount of xGNS delegated by given address to given address.
func GetDelegationAmountFromTo(from, to std.Address) uint64 {
	toAmount, exist := delegationState.DelegatedFromTo()[from.String()]
	if !exist {
		return 0
	}

	amount, exist := toAmount[to.String()]
	if !exist {
		return 0
	}

	return amount
}

// GetRealmGnsBalance returns the amount of GNS in the current realm.
func GetRealmGnsBalance() int64 {
	return gns.BalanceOf(std.OriginCaller())
}
