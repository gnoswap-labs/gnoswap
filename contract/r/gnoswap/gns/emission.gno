package gns

import (
	"chain"
	"time"

	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
)

// InitEmissionState initializes the emission schedule.
// It creates the 12-year schedule with two-year halving periods.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - createdHeight: block height when the schedule is initialized
//   - startTimestamp: Unix timestamp when emission begins
//
// Only callable by the emission contract.
func InitEmissionState(cur realm, createdHeight int64, startTimestamp int64) {
	previousRealm := cur.Previous()
	caller := previousRealm.Address()
	access.AssertIsEmission(caller)

	emissionState = NewEmissionState(createdHeight, startTimestamp)

	chain.Emit(
		"InitEmissionState",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"height", utils.FormatInt(createdHeight),
		"timestamp", utils.FormatInt(time.Now().Unix()),
		"startTimestamp", utils.FormatInt(emissionState.getStartTimestamp()),
		"endTimestamp", utils.FormatInt(emissionState.getEndTimestamp()),
	)
}
