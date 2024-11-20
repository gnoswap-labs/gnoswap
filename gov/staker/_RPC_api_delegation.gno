package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
)

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStaked() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return gns.BalanceOf(a2u(std.CurrentRealm().Addr()))
}

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStakedWithoutLockedAmount() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return gns.BalanceOf(a2u(std.CurrentRealm().Addr())) - lockedAmount
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

	amount, exist := delegatorAmount[from]
	if !exist {
		return 0
	}
	return amount
}

// GetTotalDelegatedTo returns the total amount of xGNS delegated to given address.
func GetTotalDelegatedTo(to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	amount, exist := delegatedTo[to]
	if !exist {
		return 0
	}
	return amount
}

// GetDelegationAmountFromTo returns the amount of xGNS delegated by given address to given address.
func GetDelegationAmountFromTo(from, to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	toAmount, exist := delegatedFromTo[from]
	if !exist {
		return 0
	}

	amount, exist := toAmount[to]
	if !exist {
		return 0
	}

	return amount
}
