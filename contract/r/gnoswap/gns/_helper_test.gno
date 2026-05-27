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

func resetObject(cur realm, t *testing.T) {
	t.Helper()

	resetGnsTokenObject(cur, t)
	resetEmissionState(t)
}

func resetGnsTokenObject(cur realm, t *testing.T) {
	t.Helper()

	token, privateLedger = grc20.NewToken(0, cur, "Gnoswap", "GNS", 6)
	UserTeller = token.CallerTeller()

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
func InitGnsTest(cur realm, t *testing.T) {
	t.Helper()

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(0)

	resetEmissionState(t)
}
