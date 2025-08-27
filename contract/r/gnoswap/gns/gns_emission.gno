package gns

import (
	"std"

	"gno.land/r/gnoswap/access"
)

// InitEmissionState initializes emission schedule with start timestamp.
// Only callable by emission contract. Sets up 12-year emission schedule
// with halving every 2 years. Panics if caller is not emission contract.
func InitEmissionState(cur realm, height int64, timestamp int64) {
	caller := std.PreviousRealm().Address()
	access.AssertIsEmission(caller)

	emissionState = NewEmissionState(height, timestamp)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"InitEmissionState",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"height", formatInt(height),
		"timestamp", formatInt(timestamp),
		"startTimestamp", formatInt(emissionState.getStartTimestamp()),
		"endTimestamp", formatInt(emissionState.getEndTimestamp()),
	)
}
