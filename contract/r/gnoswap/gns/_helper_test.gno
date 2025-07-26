package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"

	_ "gno.land/r/gnoswap/v1/rbac" // initialize rbac package
)

func resetObject(t *testing.T) {
	t.Helper()

	resetGnsTokenObject(t)

	height := std.ChainHeight()
	lastMintedHeight = height
}

func resetGnsTokenObject(t *testing.T) {
	t.Helper()

	token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	owner = ownable.NewWithAddress(adminAddr)

	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
}

const (
	SECONDS_PER_DAY = 86400
	// Default block generation interval, in milliseconds, used to estimate
	// how many blocks will be produced over a given timeframe.
	// GnoSwap’s emission logic relies on this as an initial value,
	// but actual block times may vary (e.g. due to network conditions).
	// Governance or an admin can adjust it dynamically by calling
	// [SetAvgBlockTimeInMs](https://github.com/gnoswap-labs/gnoswap/blob/a29e0f994466430618548ae992cca11a52f5102a/contract/r/gnoswap/gns/halving.gno#L359) to keep emission schedules accurate.
	BLOCK_GENERATION_INTERVAL int64 = 2000
	MILLISECONDS_PER_SECOND   int64 = 1000
)

// resetEmissionState resets the emission state to a clean state for testing
func resetEmissionState(t *testing.T) {
	t.Helper()

	emissionState = nil
	avgBlockTimeMs = BLOCK_GENERATION_INTERVAL
	blockPerYear = SECONDS_IN_YEAR / milliToSec(BLOCK_GENERATION_INTERVAL)
	blockPerDay = SECONDS_PER_DAY / milliToSec(BLOCK_GENERATION_INTERVAL)
}
