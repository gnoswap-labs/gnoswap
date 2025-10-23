package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

func init() {
	registerGovernanceV1()
}

func registerGovernanceV1() {
	governance.RegisterInitializer(cross, func(governanceStore governance.IGovernanceStore) governance.IGovernance {
		return NewGovernanceV1(governanceStore)
	})
}

func initStoreData(governanceStore governance.IGovernanceStore) error {
	governanceState := NewGovernanceState()

	err := governanceStore.SetGovernanceState(governanceState)
	if err != nil {
		return err
	}

	return nil
}