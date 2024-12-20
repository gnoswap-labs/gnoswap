package gns

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"

	"gno.land/r/gnoswap/v1/consts"
)

func resetObject(t *testing.T) {
	t.Helper()

	resetGnsTokenObject(t)
	resetHalvingRelatedObject(t)

	height := std.GetHeight()
	lastMintedHeight = height
	startHeight = height
	startTimestamp = time.Now().Unix()
}

func resetGnsTokenObject(t *testing.T) {
	t.Helper()

	Token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller = Token.CallerTeller()
	owner = ownable.NewWithAddress(consts.ADMIN)
	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
}

func resetHalvingRelatedObject(t *testing.T) {
	t.Helper()

	startHeight = std.GetHeight()
	startTimestamp = time.Now().Unix()

	initializeHalvingData()
	setEndTimestamp(startTimestamp + consts.TIMESTAMP_YEAR*HALVING_END_YEAR)
}
