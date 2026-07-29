package gns

import (
	"chain"
	"time"

	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
)

// InitEmissionState initializes emission schedule with start timestamp.
// Sets up 12-year emission schedule with halving every 2 years.
//
// Parameters:
//   - height: block height when emission starts
//   - timestamp: timestamp when emission starts
//
// Only callable by emission contract. Panics if caller is not emission contract.
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
