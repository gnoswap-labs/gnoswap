package v1

import (
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/gov/governance"
)

type governanceV1 struct {
	store governance.IGovernanceStore
}

func (gv *governanceV1) getGovernanceState() *governanceState {
	result, ok := gv.store.GetGovernanceState().(*governanceState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to governanceState: %T", result))
	}

	return result
}

func (gv *governanceV1) setGovernanceState(governanceState *governanceState) error {
	return gv.store.SetGovernanceState(governanceState)
}

func NewGovernanceV1(governanceStore governance.IGovernanceStore) governance.IGovernance {
	return &governanceV1{
		store: governanceStore,
	}
}
