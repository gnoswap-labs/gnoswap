package v2

import (
	"gno.land/r/gnoswap/launchpad"
)

type launchpadV1 struct {
	store launchpad.ILaunchpadStore
}

func NewLaunchpadV1(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
	return &launchpadV1{
		store: launchpadStore,
	}
}
