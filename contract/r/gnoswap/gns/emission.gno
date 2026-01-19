package gns

import (
	"chain"
	"chain/runtime"
	"time"

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
func InitEmissionState(cur realm, height int64, timestamp int64) {
// Only callable by emission contract. Sets up 12-year emission schedule
// with halving every 2 years. Panics if caller is not emission contract.
func InitEmissionState(cur realm, createdHeight int64, startTimestamp int64) {
	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsEmission(caller)

	emissionState = NewEmissionState(createdHeight, startTimestamp)

	chain.Emit(
		"InitEmissionState",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"height", formatInt(createdHeight),
		"timestamp", formatInt(time.Now().Unix()),
		"startTimestamp", formatInt(emissionState.getStartTimestamp()),
		"endTimestamp", formatInt(emissionState.getEndTimestamp()),
	)
}
