package gns

import (
	"std"

	"gno.land/r/gnoswap/access"
)

// InitEmissionState initializes the emission schedule with a new start timestamp.
//
// This function sets up the halving schedule for GNS token emissions, calculating
// when each halving period begins and ends. Called by the emission contract when
// the distribution start time is configured.
//
// Parameters:
//   - cur realm: Current execution context realm
//   - height: Block height for initialization (deprecated, kept for compatibility)
//   - timestamp: Unix timestamp when emission schedule starts
//
// Panics:
//   - Caller is not the emission contract
//
// Events:
//
//	Emits InitEmissionState event with schedule details
//
// Note:
//   - Sets up 13 halving periods (years 1-13)
//   - Each period lasts 4 years
//   - Emission rate halves each period
//   - Total emission period: 52 years
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
