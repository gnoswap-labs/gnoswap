package launchpad

import (
	"gno.land/r/gnoswap/launchpad"
)

type launchpadV1 struct {
	store launchpad.ILaunchpadStore
}

// NewLaunchpadV1 constructs a version-one launchpad implementation backed by launchpadStore.
//
// Parameters:
//   - launchpadStore: store implementation used for all launchpad state reads and writes.
//
// Returns:
//   - launchpad: launchpad implementation that delegates persistence to launchpadStore.
func NewLaunchpadV1(launchpadStore launchpad.ILaunchpadStore) launchpad.ILaunchpad {
	return &launchpadV1{
		store: launchpadStore,
	}
}
