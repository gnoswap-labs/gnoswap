package staker

import (
	"gno.land/p/demo/ufmt"
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
	delegatedAmount := int64(0)

	func(cur realm) {
		delegations.Iterate("", "", func(key string, value any) bool {
			delegation, ok := value.(*Delegation)
			if !ok {
				panic(ufmt.Sprintf("failed to cast delegations's element to *Delegation: %T", value))
			}
			delegatedAmount += delegation.DelegatedAmount()

			return false
		})
	}(cross)

	return delegatedAmount
}

// GetTotalLockedAmount returns the total amount of locked GNS.
func GetTotalLockedAmount() int64 {
	delegatedAmount := int64(0)

	func(cur realm) {
		delegations.Iterate("", "", func(key string, value any) bool {
			delegation, ok := value.(*Delegation)
			if !ok {
				panic(ufmt.Sprintf("failed to cast delegations's element to *Delegation: %T", value))
			}
			delegatedAmount += delegation.LockedAmount()

			return false
		})
	}(cross)

	return delegatedAmount
}
