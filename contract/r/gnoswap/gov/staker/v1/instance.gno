package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gov/staker"
)

type govStakerV1 struct {
	store staker.IGovStakerStore
	
	// Managers - version specific logic
	emissionRewardManager    *EmissionRewardManager
	protocolFeeRewardManager *ProtocolFeeRewardManager
	delegationManager        *DelegationManager
	
	// Launchpad integration
	launchpadProjectDeposits *avl.Tree
}

func NewGovStakerV1(store staker.IGovStakerStore) staker.IGovStaker {
	return &govStakerV1{
		store: store,
		emissionRewardManager:    NewEmissionRewardManager(),
		protocolFeeRewardManager: NewProtocolFeeRewardManager(),
		delegationManager:        NewDelegationManager(),
		launchpadProjectDeposits: avl.NewTree(),
	}
}