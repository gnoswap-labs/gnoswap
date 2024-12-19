package gns

import (
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"

	"gno.land/r/gnoswap/v1/consts"
)

func testResetGnsTokenObject(t *testing.T) {
	t.Helper()

	Token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller = Token.CallerTeller()
	owner = ownable.NewWithAddress(consts.ADMIN)

	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
}
