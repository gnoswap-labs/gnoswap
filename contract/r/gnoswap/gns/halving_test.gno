package gns

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/uassert"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
)

var (
	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)

	startHeight    int64 = std.ChainHeight()
	startTimestamp int64 = time.Now().Unix() + milliToSec(consts.BLOCK_GENERATION_INTERVAL)
)

var FIRST_BLOCK_OF_YEAR = []int64{
	startHeight + (blockPerYear * 0),
	startHeight + (blockPerYear * 1) + 1,
	startHeight + (blockPerYear * 2) + 2,
	startHeight + (blockPerYear * 3) + 3,
	startHeight + (blockPerYear * 4) + 4,
	startHeight + (blockPerYear * 5) + 5,
	startHeight + (blockPerYear * 6) + 6,
	startHeight + (blockPerYear * 7) + 7,
	startHeight + (blockPerYear * 8) + 8,
	startHeight + (blockPerYear * 9) + 9,
	startHeight + (blockPerYear * 10) + 10,
	startHeight + (blockPerYear * 11) + 11,
}

var FIRST_TIMESTAMP_OF_YEAR = []int64{
	startTimestamp + SECONDS_IN_YEAR*0,
	startTimestamp + SECONDS_IN_YEAR*1,
	startTimestamp + SECONDS_IN_YEAR*2,
	startTimestamp + SECONDS_IN_YEAR*3,
	startTimestamp + SECONDS_IN_YEAR*4,
	startTimestamp + SECONDS_IN_YEAR*5,
	startTimestamp + SECONDS_IN_YEAR*6,
	startTimestamp + SECONDS_IN_YEAR*7,
	startTimestamp + SECONDS_IN_YEAR*8,
	startTimestamp + SECONDS_IN_YEAR*9,
	startTimestamp + SECONDS_IN_YEAR*10,
	startTimestamp + SECONDS_IN_YEAR*11,
}

var END_TIMESTAMP_OF_YEAR = []int64{
	startTimestamp + SECONDS_IN_YEAR*1,
	startTimestamp + SECONDS_IN_YEAR*2,
	startTimestamp + SECONDS_IN_YEAR*3,
	startTimestamp + SECONDS_IN_YEAR*4,
	startTimestamp + SECONDS_IN_YEAR*5,
	startTimestamp + SECONDS_IN_YEAR*6,
	startTimestamp + SECONDS_IN_YEAR*7,
	startTimestamp + SECONDS_IN_YEAR*8,
	startTimestamp + SECONDS_IN_YEAR*9,
	startTimestamp + SECONDS_IN_YEAR*10,
	startTimestamp + SECONDS_IN_YEAR*11,
	startTimestamp + SECONDS_IN_YEAR*12,
}

func TestAmountByHeight(t *testing.T) {
	resetEmissionState(t)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		firstBlockOfYear := FIRST_BLOCK_OF_YEAR[year-1]
		uassert.Equal(t, GetAmountPerBlockPerHalvingYear(year), AmountByHeight(firstBlockOfYear))
		if year == HALVING_START_YEAR {
			uassert.Equal(t, GetHalvingYearAccuAmount(year), GetHalvingYearMaxAmount(year))
		} else {
			uassert.Equal(t, GetHalvingYearAccuAmount(year), GetHalvingYearAccuAmount(year-1)+GetHalvingYearMaxAmount(year))
			uassert.Equal(t, int64(1), GetHalvingYearStartBlock(year)-GetHalvingYearEndBlock(year-1))
		}
		uassert.Equal(t, blockPerYear, (GetHalvingYearEndBlock(year) - GetHalvingYearStartBlock(year) + 1))

		if year == HALVING_START_YEAR {
			uassert.Equal(t, GetHalvingYearMaxAmount(year)+GetAmountPerBlockPerHalvingYear(year+1), calculateAmountToMint(GetHalvingYearStartBlock(year), GetHalvingYearStartBlock(year+1)))
		} else if year == HALVING_END_YEAR {
			uassert.Equal(t, GetHalvingYearMaxAmount(year)-GetAmountPerBlockPerHalvingYear(year), calculateAmountToMint(GetHalvingYearStartBlock(year)+1, GetHalvingYearEndBlock(year)+1))
		} else {
			uassert.Equal(t, GetHalvingYearMaxAmount(year)-GetAmountPerBlockPerHalvingYear(year)+GetAmountPerBlockPerHalvingYear(year+1), calculateAmountToMint(GetHalvingYearStartBlock(year)+1, GetHalvingYearStartBlock(year+1)))
		}
	}
}

func TestHalvingYearByHeight(t *testing.T) {
	resetEmissionState(t)

	t.Run("during halving years", func(t *testing.T) {
		for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
			firstBlockOfYear := FIRST_BLOCK_OF_YEAR[year-1]
			uassert.Equal(t, year, HalvingYearByHeight(firstBlockOfYear))
		}
	})

	t.Run("no year after 12 years", func(t *testing.T) {
		uassert.Equal(t, int64(0), HalvingYearByHeight(GetEndHeight()+1))
	})
}

func TestGetHalvingYearAndEndTimestamp(t *testing.T) {
	resetEmissionState(t)

	t.Run("bit of extra timestamp for each year", func(t *testing.T) {
		for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
			firstTimestampOfYear := FIRST_TIMESTAMP_OF_YEAR[year-1]
			gotYear, gotEndTimestamp := getHalvingYearAndEndTimestamp(firstTimestampOfYear + 5) // after 5s
			uassert.Equal(t, year, gotYear)
			uassert.Equal(t, gotEndTimestamp, END_TIMESTAMP_OF_YEAR[year-1])
		}
	})

	t.Run("after 12 years", func(t *testing.T) {
		year, endTimestamp := getHalvingYearAndEndTimestamp(endTimestamp() + 1)
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
	uassert.Equal(t, GetHalvingYearMaxAmount(3), int64(300))
}

func TestHalvingYearMintAmount(t *testing.T) {
	setHalvingYearMintAmount(4, 400)
	uassert.Equal(t, GetHalvingYearMintAmount(4), int64(400))
}

func TestHalvingYearAccuAmount(t *testing.T) {
	setHalvingYearAccuAmount(5, 500)
	uassert.Equal(t, GetHalvingYearAccuAmount(5), int64(500))
}

func TestAmountPerBlockPerHalvingYear(t *testing.T) {
	setAmountPerBlockPerHalvingYear(6, 600)
	uassert.Equal(t, GetAmountPerBlockPerHalvingYear(6), int64(600))
}

func TestGetHalvingInfo(t *testing.T) {
	jsonStr, err := json.Unmarshal([]byte(GetHalvingInfo()))
	uassert.NoError(t, err)

	halving := jsonStr.MustKey("halvings").MustArray()
	uassert.Equal(t, len(halving), 12)
}

func TestSetAvgBlockTime_InvalidIntervalErrors(t *testing.T) {
	testing.SetRealm(std.NewUserRealm(adminAddr))

	err := setAvgBlockTimeInMs(0)
	uassert.ErrorIs(t, errInvalidAvgBlockTimeInMs, err)

	err = setAvgBlockTimeInMs(-5)
	uassert.ErrorIs(t, errInvalidAvgBlockTimeInMs, err)
}

func TestSetAvgBlockTime_CallbackInvocation(t *testing.T) {
	/*
		Test that the function registered with emissionChangeCallback
		accepts the amountPerBlock value of the "current year" as an argument,
		and only once.
	*/
	called := 0
	var received int64
	oldCb := emissionChangeCallback
	emissionChangeCallback = func(a int64) {
		called++
		received = a
	}
	defer func() { emissionChangeCallback = oldCb }()

	// assume current block height is at the first year boundary
	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)
	setAvgBlockTimeInMs(1000)

	uassert.Equal(t, 1, called)
	es := GetEmissionState()
	expected := es.halvingData.getAmountPerBlock(1)
	uassert.Equal(t, expected, received)
}

func TestSetAvgBlockTime_RecalculatesAllYears(t *testing.T) {
	/*
		Test that the "issuance per block" is actually reallocated
		by comparing the value of the amountPerBlock array before and after the call.
	*/
	resetEmissionState(t)

	es := GetEmissionState()
	before := make([]int64, HALVING_END_YEAR)
	for y := int64(1); y <= HALVING_END_YEAR; y++ {
		before[y-1] = es.halvingData.getAmountPerBlock(y)
	}

	// ignore callback in test
	oldCallback := emissionChangeCallback
	emissionChangeCallback = func(amount int64) {}
	defer func() { emissionChangeCallback = oldCallback }()

	testing.SkipHeights(1)
	testing.SetRealm(adminRealm)
	setAvgBlockTimeInMs(before[0] + 100) // increase block time

	for y := int64(1); y <= HALVING_END_YEAR; y++ {
		after := es.halvingData.getAmountPerBlock(y)
		if before[y-1] == 0 {
			// case 1: before is 0
			// still 0 because of the rounding down
			uassert.Equal(
				t,
				int64(0),
				after,
				ufmt.Sprintf("year %d should stay zero, got %d", y, after),
			)
		} else {
			// case 2: before > 0
			// check if the amount per block has increased
			uassert.True(
				t,
				after > before[y-1],
				ufmt.Sprintf(
					"year %d not recalculated: before=%d, after=%d",
					y, before[y-1], after,
				),
			)
		}
	}
}

func TestSetAvgBlockTimeInMsByAdmin(t *testing.T) {
	t.Run("panic if caller is not admin", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}
		uassert.AbortsWithMessage(t,
			"unauthorized: caller g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh is not admin",
			func() {
				testing.SetOriginCaller(alice)
				testing.SetRealm(std.NewUserRealm(alice))
				SetAvgBlockTimeInMsByAdmin(cross, 1)
			},
		)
		emissionChangeCallback = oldCallback
	})

	t.Run("success if caller is admin", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}

		testing.SkipHeights(1)
		testing.SetRealm(std.NewUserRealm(adminAddr))
		SetAvgBlockTimeInMsByAdmin(cross, 2)
		uassert.Equal(t, AvgBlockTimeInMs(), int64(2))

		emissionChangeCallback = oldCallback
	})

	t.Run("panic with negative block time", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}
		testing.SkipHeights(1)
		testing.SetRealm(std.NewUserRealm(adminAddr))
		uassert.AbortsWithMessage(t,
			errInvalidAvgBlockTimeInMs.Error(),
			func() {
				SetAvgBlockTimeInMsByAdmin(cross, -1)
			},
		)
		emissionChangeCallback = oldCallback
	})

	t.Run("panic with extremely large block time", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}
		testing.SkipHeights(1)
		testing.SetRealm(std.NewUserRealm(adminAddr))
		uassert.AbortsWithMessage(t,
			"[GNOSWAP-GNS-004] invalid avg block time in ms",
			func() {
				SetAvgBlockTimeInMsByAdmin(cross, MAX_BLOCK_TIME_MS)
			},
		)
		emissionChangeCallback = oldCallback
	})
}

func TestSetAvgBlockTimeInMs(t *testing.T) {
	t.Run("panic if caller is not governance contract", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}

		expectedMsg := "unauthorized: caller g1jgqwaa2le3yr63d533fj785qkjspumzv22ys5m is not governance"
		uassert.AbortsWithMessage(t,
			expectedMsg,
			func() {
				SetAvgBlockTimeInMs(cross, 3)
			},
		)
		emissionChangeCallback = oldCallback
	})

	t.Run("success if caller is governance contract", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}

		testing.SkipHeights(3)
		testing.SetRealm(govRealm)
		SetAvgBlockTimeInMs(cross, 4)

		uassert.Equal(t, AvgBlockTimeInMs(), int64(4))
		emissionChangeCallback = oldCallback
	})

	t.Run("panic with negative block time", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}

		testing.SkipHeights(1)
		testing.SetRealm(govRealm)
		uassert.AbortsWithMessage(t,
			"[GNOSWAP-GNS-004] invalid avg block time in ms",
			func() {
				SetAvgBlockTimeInMs(cross, -1)
			},
		)
		emissionChangeCallback = oldCallback
	})

	t.Run("panic with extremely large block time", func(t *testing.T) {
		oldCallback := emissionChangeCallback
		emissionChangeCallback = func(amount int64) {}

		testing.SkipHeights(1)
		testing.SetRealm(govRealm)
		uassert.AbortsWithMessage(t,
			"[GNOSWAP-GNS-004] invalid avg block time in ms",
			func() {
				SetAvgBlockTimeInMs(cross, MAX_BLOCK_TIME_MS)
			},
		)
		emissionChangeCallback = oldCallback
	})
}

func TestGetEmission(t *testing.T) {
	t.Run("emission during halving year", func(t *testing.T) {
		year := HALVING_START_YEAR
		initialMinted := int64(1000)
		initialLeft := int64(5000)
		amountPerBlock := int64(100)

		// Set the current block height to be within the first halving year
		currentHeight := GetHalvingYearStartBlock(year) + 10

		// Set up the test state
		setHalvingYearMintAmount(year, initialMinted)
		setHalvingYearLeftAmount(year, initialLeft)
		setAmountPerBlockPerHalvingYear(year, amountPerBlock)

		testing.SetHeight(currentHeight)

		// Call GetEmission multiple times and verify the updated state
		for range make([]struct{}, 3) {
			// Record state before the call
			mintedBefore := GetHalvingYearMintAmount(year)
			leftBefore := GetHalvingYearLeftAmount(year)

			// Call GetEmission function
			amount := GetEmission()

			// Verify that the returned amount matches the expected amount
			uassert.Equal(t, amountPerBlock, amount)

			// Verify that mintedAmount was updated correctly
			expectedMinted := mintedBefore + amountPerBlock
			actualMinted := GetHalvingYearMintAmount(year)
			uassert.Equal(t, expectedMinted, actualMinted)

			// Verify that leftAmount was updated correctly
			expectedLeft := leftBefore - amountPerBlock
			actualLeft := GetHalvingYearLeftAmount(year)
			uassert.Equal(t, expectedLeft, actualLeft)
		}

		// Check final results
		finalMinted := GetHalvingYearMintAmount(year)
		finalLeft := GetHalvingYearLeftAmount(year)

		// Verify that the 3 updates from the initial value were accurately reflected
		uassert.Equal(t, initialMinted+(amountPerBlock*3), finalMinted)
		uassert.Equal(t, initialLeft-(amountPerBlock*3), finalLeft)
	})

	t.Run("emission outside halving year range", func(t *testing.T) {
		// Set the block height to a value after all halving years have ended
		endHeight := GetEndHeight()
		testing.SetHeight(endHeight + 1)

		// Store initial state
		year := HALVING_END_YEAR
		mintedBefore := GetHalvingYearMintAmount(year)
		leftBefore := GetHalvingYearLeftAmount(year)

		amount := GetEmission()

		// Verify that the returned amount is 0 (no emission after halving period)
		uassert.Equal(t, int64(0), amount)

		// Verify that mintedAmount and leftAmount were not changed
		uassert.Equal(t, mintedBefore, GetHalvingYearMintAmount(year))
		uassert.Equal(t, leftBefore, GetHalvingYearLeftAmount(year))
	})

	t.Run("emission at year boundary", func(t *testing.T) {
		// Years to test
		years := []int64{HALVING_START_YEAR, HALVING_START_YEAR + 1}

		for _, year := range years {
			// Get the start and end heights for each year
			startHeight := GetHalvingYearStartBlock(year)
			endHeight := GetHalvingYearEndBlock(year)

			// Test at the start and end blocks
			testBoundaryHeights := []int64{startHeight, endHeight}

			for _, height := range testBoundaryHeights {
				// Test setup
				amountPerBlock := GetAmountPerBlockPerHalvingYear(year)
				initialMinted := int64(500)
				initialLeft := int64(10000)

				// Set state
				setHalvingYearMintAmount(year, initialMinted)
				setHalvingYearLeftAmount(year, initialLeft)

				// Set current height
				testing.SetHeight(height)

				// Call GetEmission
				amount := GetEmission()

				// Verify that the returned amount matches the expected amount
				uassert.Equal(t, amountPerBlock, amount)

				// Verify mintedAmount
				uassert.Equal(t, initialMinted+amountPerBlock, GetHalvingYearMintAmount(year))

				// Verify leftAmount
				uassert.Equal(t, initialLeft-amountPerBlock, GetHalvingYearLeftAmount(year))
			}
		}
	})
}

// TestGetHalvingYearAndEndTimestampValidation tests various scenarios for getHalvingYearAndEndTimestamp
// to ensure proper validation and handling of edge cases
func TestGetHalvingYearAndEndTimestampValidation(t *testing.T) {
	resetEmissionState(t)

	es := GetEmissionState()

	tests := []struct {
		name            string
		timestampOffset int64 // offset from start timestamp
		expectedYear    int64
		expectedEndTime int64
		description     string
	}{
		{
			name:            "Before emission start",
			timestampOffset: -1000,
			expectedYear:    1,
			expectedEndTime: es.getStartTimestamp() + SECONDS_IN_YEAR,
			description:     "Should return year 1 even before emission starts",
		},
		{
			name:            "Start of emission",
			timestampOffset: 0,
			expectedYear:    1,
			expectedEndTime: es.getStartTimestamp() + SECONDS_IN_YEAR,
			description:     "Should return year 1 at emission start",
		},
		{
			name:            "Middle of year 1",
			timestampOffset: SECONDS_IN_YEAR / 2,
			expectedYear:    1,
			expectedEndTime: es.getStartTimestamp() + SECONDS_IN_YEAR,
			description:     "Should return year 1 in the middle of first year",
		},
		{
			name:            "End of year 1",
			timestampOffset: SECONDS_IN_YEAR - 1,
			expectedYear:    1,
			expectedEndTime: es.getStartTimestamp() + SECONDS_IN_YEAR,
			description:     "Should return year 1 at the end of first year",
		},
		{
			name:            "Start of year 2",
			timestampOffset: SECONDS_IN_YEAR,
			expectedYear:    2,
			expectedEndTime: es.getStartTimestamp() + (SECONDS_IN_YEAR * 2),
			description:     "Should return year 2 at the start of second year",
		},
		{
			name:            "Middle of year 6",
			timestampOffset: (SECONDS_IN_YEAR * 5) + (SECONDS_IN_YEAR / 2),
			expectedYear:    6,
			expectedEndTime: es.getStartTimestamp() + (SECONDS_IN_YEAR * 6),
			description:     "Should return year 6 in the middle of sixth year",
		},
		{
			name:            "Start of year 12",
			timestampOffset: SECONDS_IN_YEAR * 11,
			expectedYear:    12,
			expectedEndTime: es.getStartTimestamp() + (SECONDS_IN_YEAR * 12),
			description:     "Should return year 12 at the start of final year",
		},
		{
			name:            "End of year 12",
			timestampOffset: (SECONDS_IN_YEAR * 12) - 1,
			expectedYear:    12,
			expectedEndTime: es.getStartTimestamp() + (SECONDS_IN_YEAR * 12),
			description:     "Should return year 12 at the end of emission period",
		},
		{
			name:            "Exactly at emission end",
			timestampOffset: SECONDS_IN_YEAR * 12,
			expectedYear:    13,
			expectedEndTime: es.getStartTimestamp() + (SECONDS_IN_YEAR * 13),
			description:     "Should return year 13 exactly at emission end timestamp (edge case)",
		},
		{
			name:            "Just after emission end",
			timestampOffset: (SECONDS_IN_YEAR * 12) + 1,
			expectedYear:    0,
			expectedEndTime: 0,
			description:     "Should return (0, 0) immediately after emission ends",
		},
		{
			name:            "Far after emission end",
			timestampOffset: SECONDS_IN_YEAR * 20,
			expectedYear:    0,
			expectedEndTime: 0,
			description:     "Should return (0, 0) far after emission ends",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			timestamp := es.getStartTimestamp() + tt.timestampOffset
			year, endTime := getHalvingYearAndEndTimestamp(timestamp)

			uassert.Equal(t, tt.expectedYear, year,
				"Year mismatch for %s: %s", tt.name, tt.description)
			uassert.Equal(t, tt.expectedEndTime, endTime,
				"End time mismatch for %s: %s", tt.name, tt.description)
		})
	}
}

// TestHalvingDataGettersWithInvalidYear tests that HalvingData getters handle invalid years properly
func TestHalvingDataGettersWithInvalidYear(t *testing.T) {
	resetEmissionState(t)

	hd := &HalvingData{
		startBlockHeight: make([]int64, HALVING_END_YEAR),
		endBlockHeight:   make([]int64, HALVING_END_YEAR),
		startTimestamp:   make([]int64, HALVING_END_YEAR),
		maxAmount:        make([]int64, HALVING_END_YEAR),
		mintedAmount:     make([]int64, HALVING_END_YEAR),
		leftAmount:       make([]int64, HALVING_END_YEAR),
		accumAmount:      make([]int64, HALVING_END_YEAR),
		amountPerBlock:   make([]int64, HALVING_END_YEAR),
	}

	// Set test values for valid years
	for i := int64(0); i < HALVING_END_YEAR; i++ {
		hd.startBlockHeight[i] = 1000 + i*100
		hd.endBlockHeight[i] = 2000 + i*100
		hd.startTimestamp[i] = 3000 + i*100
		hd.maxAmount[i] = 4000 + i*100
		hd.mintedAmount[i] = 5000 + i*100
		hd.leftAmount[i] = 6000 + i*100
		hd.accumAmount[i] = 7000 + i*100
		hd.amountPerBlock[i] = 8000 + i*100
	}

	tests := []struct {
		name     string
		year     int64
		getter   func(int64) int64
		expected int64
	}{
		// Year 0 tests (should return 0)
		{"StartBlockHeight with year 0", 0, hd.getStartBlockHeight, 0},
		{"EndBlockHeight with year 0", 0, hd.getEndBlockHeight, 0},
		{"StartTimestamp with year 0", 0, hd.getStartTimestamp, 0},
		{"MaxAmount with year 0", 0, hd.getMaxAmount, 0},
		{"MintedAmount with year 0", 0, hd.getMintedAmount, 0},
		{"LeftAmount with year 0", 0, hd.getLeftAmount, 0},
		{"AccumAmount with year 0", 0, hd.getAccumAmount, 0},
		{"AmountPerBlock with year 0", 0, hd.getAmountPerBlock, 0},

		// Year -1 tests (negative year, should return 0)
		{"StartBlockHeight with year -1", -1, hd.getStartBlockHeight, 0},

		// Valid year tests
		{"StartBlockHeight with year 1", 1, hd.getStartBlockHeight, 1000},
		{"EndBlockHeight with year 1", 1, hd.getEndBlockHeight, 2000},
		{"StartTimestamp with year 1", 1, hd.getStartTimestamp, 3000},
		{"MaxAmount with year 1", 1, hd.getMaxAmount, 4000},
		{"MintedAmount with year 1", 1, hd.getMintedAmount, 5000},
		{"LeftAmount with year 1", 1, hd.getLeftAmount, 6000},
		{"AccumAmount with year 1", 1, hd.getAccumAmount, 7000},
		{"AmountPerBlock with year 1", 1, hd.getAmountPerBlock, 8000},

		// Last valid year tests
		{"StartBlockHeight with year 12", 12, hd.getStartBlockHeight, 2100},
		{"EndBlockHeight with year 12", 12, hd.getEndBlockHeight, 3100},
		{"StartTimestamp with year 12", 12, hd.getStartTimestamp, 4100},
		{"MaxAmount with year 12", 12, hd.getMaxAmount, 5100},
		{"MintedAmount with year 12", 12, hd.getMintedAmount, 6100},
		{"LeftAmount with year 12", 12, hd.getLeftAmount, 7100},
		{"AccumAmount with year 12", 12, hd.getAccumAmount, 8100},
		{"AmountPerBlock with year 12", 12, hd.getAmountPerBlock, 9100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.getter(tt.year)
			uassert.Equal(t, tt.expected, result,
				"Unexpected result for %s", tt.name)
		})
	}
}
