package v1

import (
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/gov/governance"
)

type governanceV1 struct {
	store governance.IGovernanceStore
}

func (gv *governanceV1) HasGovernanceStateStoreKey() bool {
	return gv.store.HasGovernanceStateStoreKey()
}

func (gv *governanceV1) GetGovernanceState() *governanceState {
	result, ok := gv.store.GetGovernanceState().(*governanceState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to governanceState: %T", result))
	}

	return result
}

func (gv *governanceV1) SetGovernanceState(governanceState *governanceState) error {
	return gv.store.SetGovernanceState(governanceState)
}

func (gv *governanceV1) HasProposalNextIDStoreKey() bool {
	return gv.store.HasProposalNextIDStoreKey()
}

func (gv *governanceV1) GetProposalNextID() uint64 {
	return gv.store.GetProposalNextID()
}

func (gv *governanceV1) SetProposalNextID(nextID uint64) error {
	return gv.store.SetProposalNextID(nextID)
}

func NewGovernanceV1(governanceStore governance.IGovernanceStore) governance.IGovernance {
	return &governanceV1{
		store: governanceStore,
	}
}
