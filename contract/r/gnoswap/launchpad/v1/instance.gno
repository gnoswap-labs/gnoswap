package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"
)

type launchpadV1 struct {
	store launchpad.ILaunchpadStore
}

func (lp *launchpadV1) getLaunchpadState() *launchpadState {
	result, ok := lp.store.GetLaunchpadState().(*launchpadState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to launchpadState: %T", result))
	}

	return result
}

func (lp *launchpadV1) setLaunchpadState(launchpadState *launchpadState) error {
	return lp.store.SetLaunchpadState(launchpadState)
}

func NewLaunchpadV1(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
	return &launchpadV1{
		store: launchpadStore,
	}
}
