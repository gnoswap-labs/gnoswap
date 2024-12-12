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

	for year := int64(1); year < 13; year++ {
		setHalvingYearMaxAmount(year, HALVING_AMOUNTS[year-1])

		if year == 1 {
			setHalvingYearAccuAmount(year, HALVING_AMOUNTS[year-1])
		} else {
			setHalvingYearAccuAmount(year, GetHalvingYearAccuAmount(year-1)+HALVING_AMOUNTS[year-1])
		}

		setHalvingYearBlock(year, startHeight+BLOCK_PER_YEAR*year)
		setHalvingYearTimestamp(year, startTimestamp+(consts.TIMESTAMP_YEAR*year))
		setHalvingYearMintAmount(year, uint64(0))

		amountPerYear := GetHalvingYearMaxAmount(year)         // amount per year
		amountPerDay := amountPerYear / consts.DAY_PER_YEAR    // amount per day
		amountPerBlock := amountPerDay / uint64(BLOCK_PER_DAY) // amount per block
		setAmountPerBlockPerHalvingYear(year, uint64(amountPerBlock))
	}
}
