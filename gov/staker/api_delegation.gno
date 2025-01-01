package staker

import (
	"std"

	"gno.land/p/demo/avl"

	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStaked() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return getRealmGnsBalance()
}

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStakedWithoutLockedAmount() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return getRealmGnsBalance() - lockedAmount
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func GetTotalDelegated() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return totalDelegated
}

// GetTotalDelegatedFrom returns the total amount of xGNS delegated by given address.
func GetTotalDelegatedFrom(from std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	amount, exist := delegatorAmount.Get(from.String())
	if !exist {
		return 0
	}
	return amount.(uint64)
}

// GetTotalDelegatedTo returns the total amount of xGNS delegated to given address.
func GetTotalDelegatedTo(to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	amount, exist := delegatedTo.Get(to.String())
	if !exist {
		return 0
	}
	return amount.(uint64)
}

// GetDelegationAmountFromTo returns the amount of xGNS delegated by given address to given address.
func GetDelegationAmountFromTo(from, to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

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
