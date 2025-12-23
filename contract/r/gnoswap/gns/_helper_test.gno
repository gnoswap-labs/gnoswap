package gns

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc20"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

var adminAddr = access.MustGetAddress(prabc.ROLE_ADMIN.String())

func resetObject(t *testing.T) {
	t.Helper()

	resetGnsTokenObject(t)
	resetEmissionState(t)
}

func resetGnsTokenObject(t *testing.T) {
	t.Helper()

	token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)

	privateLedger.Mint(adminAddr, INITIAL_MINT_AMOUNT)
}

// resetEmissionState resets the emission state to a clean state for testing
func resetEmissionState(t *testing.T) {
	t.Helper()

	blockHeight := runtime.ChainHeight()
	startTimestamp := time.Now().Unix()
	emissionState = NewEmissionState(blockHeight, startTimestamp)
}

// InitGnsTest initializes GNS state for testing by resetting emission amounts and state.
// Matches init() function: lastMintedTimestamp starts at 0 (never minted).
func InitGnsTest(t *testing.T) {
	t.Helper()

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(0)
	burnAmount = 0

	emissionState = NewEmissionState(0, 0)
}
