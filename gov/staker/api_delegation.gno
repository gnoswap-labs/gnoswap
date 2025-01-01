package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/r/gnoswap/v1/gns"
)

// GetTotalStaked returns the total amount of GNS staked.
func GetGNSBalanceOfGovStaker() uint64 {
	// TODO:
	// totalDelegated
	return getRealmGnsBalance()
}

func GetTotalStaked() uint64 {
	// TODO:
	// xGNS의 Total Total Supply
	return getRealmGnsBalance()
}

func GetTotalVoteWeight() uint64 {
	// TODO:
	// xGNS의 Vote Supply
	return getRealmGnsBalance()
}

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStakedWithoutLockedAmount() uint64 {
	// TODO:
	// totalDelegated(GetTotalDelegated()) - lockedAmount(GetTotalLockedAmount())
	return getRealmGnsBalance() - lockedAmount
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func GetTotalDelegated() uint64 {
	return totalDelegated
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func GetTotalLockedAmount() uint64 {
	return lockedAmount
}

// GetTotalDelegatedFrom returns the total amount of xGNS delegated by given address.
func GetTotalDelegatedFrom(from std.Address) uint64 {
	amount, exist := delegatorAmount.Get(from.String())
	if !exist {
		return 0
	}
	return amount.(uint64)
}

// GetTotalDelegatedTo returns the total amount of xGNS delegated to given address.
func GetTotalDelegatedTo(to std.Address) uint64 {
	amount, exist := delegatedTo.Get(to.String())
	if !exist {
		return 0
	}
	return amount.(uint64)
}

// GetDelegationAmountFromTo returns the amount of xGNS delegated by given address to given address.
func GetDelegationAmountFromTo(from, to std.Address) uint64 {
	toAmount, exist := delegatedFromTo.Get(from.String())
	if !exist {
		return 0
	}

	amount, exist := toAmount.(*avl.Tree).Get(to.String())
	if !exist {
		return 0
	}

	return amount.(uint64)
}

func getRealmGnsBalance() uint64 {
	return gns.BalanceOf(a2u(std.CurrentRealm().Addr()))
}
