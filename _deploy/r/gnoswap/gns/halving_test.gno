package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/json"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

var LAST_BLOCK_OF_YEAR = []int64{
	0,
	startHeight + BLOCK_PER_YEAR*1,
	startHeight + BLOCK_PER_YEAR*2,
	startHeight + BLOCK_PER_YEAR*3,
	startHeight + BLOCK_PER_YEAR*4,
	startHeight + BLOCK_PER_YEAR*5,
	startHeight + BLOCK_PER_YEAR*6,
	startHeight + BLOCK_PER_YEAR*7,
	startHeight + BLOCK_PER_YEAR*8,
	startHeight + BLOCK_PER_YEAR*9,
	startHeight + BLOCK_PER_YEAR*10,
	startHeight + BLOCK_PER_YEAR*11,
	startHeight + BLOCK_PER_YEAR*12,
}

var LAST_TIMESTAMP_OF_YEAR = []int64{
	0,
	startTimestamp + consts.TIMESTAMP_YEAR*1,
	startTimestamp + consts.TIMESTAMP_YEAR*2,
	startTimestamp + consts.TIMESTAMP_YEAR*3,
	startTimestamp + consts.TIMESTAMP_YEAR*4,
	startTimestamp + consts.TIMESTAMP_YEAR*5,
	startTimestamp + consts.TIMESTAMP_YEAR*6,
	startTimestamp + consts.TIMESTAMP_YEAR*7,
	startTimestamp + consts.TIMESTAMP_YEAR*8,
	startTimestamp + consts.TIMESTAMP_YEAR*9,
	startTimestamp + consts.TIMESTAMP_YEAR*10,
	startTimestamp + consts.TIMESTAMP_YEAR*11,
	startTimestamp + consts.TIMESTAMP_YEAR*12,
}

func TestSetAvgBlockTimeInMsByAdmin(t *testing.T) {
	t.Run("panic if caller is not admin", func(t *testing.T) {
		uassert.PanicsWithMessage(t,
			"caller(g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm) has no permission",
			func() {
				SetAvgBlockTimeInMsByAdmin(1)
			},
		)
	})

	t.Run("success if caller is admin", func(t *testing.T) {
		std.TestSkipHeights(1)
		std.TestSetRealm(adminRealm)
		SetAvgBlockTimeInMsByAdmin(2)
		uassert.Equal(t, GetAvgBlockTimeInMs(), int64(2))
	})
}

func TestSetAvgBlockTimeInMs(t *testing.T) {
	t.Run("panic if caller is not governance contract", func(t *testing.T) {
		uassert.PanicsWithMessage(t,
			"caller(g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm) has no permission",
			func() {
				SetAvgBlockTimeInMs(3)
			},
		)
	})

	t.Run("success if caller is governance contract", func(t *testing.T) {
		std.TestSkipHeights(3)
		std.TestSetRealm(govRealm)
		SetAvgBlockTimeInMs(4)
		uassert.Equal(t, GetAvgBlockTimeInMs(), int64(4))
	})

	// reset to default for further test
	setAvgBlockTimeInMs(consts.SECOND_IN_MILLISECOND * consts.BLOCK_GENERATION_INTERVAL)
}

func TestGetAmountByHeight(t *testing.T) {
	for year := int64(1); year <= MAX_HALVING_YEAR; year++ {
		lastBlockOfYear := LAST_BLOCK_OF_YEAR[year]
		uassert.Equal(t, GetAmountPerBlockPerHalvingYear(year), GetAmountByHeight(lastBlockOfYear))
	}
}

func TestGetHalvingYearByHeight(t *testing.T) {
	for year := int64(1); year <= MAX_HALVING_YEAR; year++ {
		lastBlockOfYear := LAST_BLOCK_OF_YEAR[year]
		uassert.Equal(t, year, GetHalvingYearByHeight(lastBlockOfYear))
	}
}

func TestGetHalvingYearAndEndTimestamp(t *testing.T) {
	for year := int64(1); year <= MAX_HALVING_YEAR; year++ {
		lastTimestampOfYear := LAST_TIMESTAMP_OF_YEAR[year]
		gotYear, gotEndTimestamp := getHalvingYearAndEndTimestamp(lastTimestampOfYear)
		uassert.Equal(t, year, gotYear)
		uassert.Equal(t, LAST_TIMESTAMP_OF_YEAR[year], gotEndTimestamp)
	}
}

func TestHalvingYearBlock(t *testing.T) {
	setHalvingYearBlock(1, 100)
	uassert.Equal(t, GetHalvingYearBlock(1), int64(100))
}

func TestHalvingYearTimestamp(t *testing.T) {
	setHalvingYearTimestamp(2, 200)
	uassert.Equal(t, GetHalvingYearTimestamp(2), int64(200))
}

func TestHalvingYearMaxAmount(t *testing.T) {
	setHalvingYearMaxAmount(3, 300)
	uassert.Equal(t, GetHalvingYearMaxAmount(3), uint64(300))
}

func TestHalvingYearMintAmount(t *testing.T) {
	setHalvingYearMintAmount(4, 400)
	uassert.Equal(t, GetHalvingYearMintAmount(4), uint64(400))
}

func TestHalvingYearAccuAmount(t *testing.T) {
	setHalvingYearAccuAmount(5, 500)
	uassert.Equal(t, GetHalvingYearAccuAmount(5), uint64(500))
}

func TestAmountPerBlockPerHalvingYear(t *testing.T) {
	setAmountPerBlockPerHalvingYear(6, 600)
	uassert.Equal(t, GetAmountPerBlockPerHalvingYear(6), uint64(600))
}

func TestGetHalvingInfo(t *testing.T) {
	jsonStr, err := json.Unmarshal([]byte(GetHalvingInfo()))
	uassert.NoError(t, err)

	halving := jsonStr.MustKey("halvings").MustArray()
	uassert.Equal(t, len(halving), 12)
}
