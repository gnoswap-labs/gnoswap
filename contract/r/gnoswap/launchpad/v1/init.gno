package v1

import (
	"gno.land/r/gnoswap/launchpad"
)

func init() {
	registerLaunchpadV1()
}

func registerLaunchpadV1() {
	launchpad.RegisterInitializer(cross, func(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		initStoreData(launchpadStore)

		return NewLaunchpadV1(launchpadStore)
	})
}

func initStoreData(launchpadStore launchpad.ILaunchpadStore) {
	launchpadState := NewLaunchpadState()

	err := launchpadStore.SetLaunchpadState(launchpadState)
	if err != nil {
		panic(err)
	}
}
