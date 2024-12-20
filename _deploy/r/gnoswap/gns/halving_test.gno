package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/json"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

var (
	govRealm   = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
	adminRealm = std.NewUserRealm(consts.ADMIN)
)

var FIRST_BLOCK_OF_YEAR = []int64{
	startHeight + (blockPerYear * 0) + 1,
	startHeight + (blockPerYear * 1) + 2,
	startHeight + (blockPerYear * 2) + 3,
	startHeight + (blockPerYear * 3) + 4,
	startHeight + (blockPerYear * 4) + 5,
	startHeight + (blockPerYear * 5) + 6,
	startHeight + (blockPerYear * 6) + 7,
	startHeight + (blockPerYear * 7) + 8,
	startHeight + (blockPerYear * 8) + 9,
	startHeight + (blockPerYear * 9) + 10,
	startHeight + (blockPerYear * 10) + 11,
	startHeight + (blockPerYear * 11) + 12,
}

var FIRST_TIMESTAMP_OF_YEAR = []int64{
	startTimestamp + consts.TIMESTAMP_YEAR*0,
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
}

var END_TIMESTAMP_OF_YEAR = []int64{
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

func TestGetAmountByHeight(t *testing.T) {
	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		firstBlockOfYear := FIRST_BLOCK_OF_YEAR[year-1]
		uassert.Equal(t, GetAmountPerBlockPerHalvingYear(year), GetAmountByHeight(firstBlockOfYear))
	}
}

func TestGetHalvingYearByHeight(t *testing.T) {
	t.Run("during halving years", func(t *testing.T) {
		for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
			firstBlockOfYear := FIRST_BLOCK_OF_YEAR[year-1]
			uassert.Equal(t, year, GetHalvingYearByHeight(firstBlockOfYear))
		}
	})

	t.Run("no year after 12 years", func(t *testing.T) {
		uassert.Equal(t, int64(0), GetHalvingYearByHeight(GetEndHeight()+1))
	})
}

func TestGetHalvingYearAndEndTimestamp(t *testing.T) {
	t.Run("bit of extra timestamp for each year", func(t *testing.T) {
		for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
			firstTimestampOfYear := FIRST_TIMESTAMP_OF_YEAR[year-1]
			gotYear, gotEndTimestamp := getHalvingYearAndEndTimestamp(firstTimestampOfYear + 5) // after 5s
			uassert.Equal(t, year, gotYear)
			uassert.Equal(t, gotEndTimestamp, END_TIMESTAMP_OF_YEAR[year-1])
		}
	})

	t.Run("after 12 years", func(t *testing.T) {
		year, endTimestamp := getHalvingYearAndEndTimestamp(GetEndTimestamp() + 1)
		uassert.Equal(t, int64(0), year)
		uassert.Equal(t, int64(0), endTimestamp)
	})
}

func TestHalvingYearStartBlock(t *testing.T) {
	setHalvingYearStartBlock(1, 100)
	uassert.Equal(t, GetHalvingYearStartBlock(1), int64(100))
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
}
