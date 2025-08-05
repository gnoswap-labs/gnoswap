package gns

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"

	_ "gno.land/r/gnoswap/v1/rbac" // initialize rbac package
)

func resetObject(t *testing.T) {
	t.Helper()

	resetGnsTokenObject(t)
	resetEmissionState(t)
}

func resetGnsTokenObject(t *testing.T) {
	t.Helper()

	token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	owner = ownable.NewWithAddress(adminAddr)

	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
}

// resetEmissionState resets the emission state to a clean state for testing
func resetEmissionState(t *testing.T) {
	t.Helper()

	blockHeight := std.ChainHeight()
	startTimestamp := time.Now().Unix()
	emissionState = NewEmissionState(blockHeight, startTimestamp)
}
