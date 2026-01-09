package gns

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

const (
	// gnoVM test context default height
	// ref: https://github.com/gnolang/gno/blob/a85a53d5b38f0a21d66262a823a8b07f4f836b68/gnovm/pkg/test/test.go#L31-L32
	GNO_VM_DEFAULT_HEIGHT = int64(123)
)

var (
	emissionRealm = testing.NewCodeRealm("gno.land/r/gnoswap/emission")
	adminRealm    = testing.NewUserRealm(adminAddr)
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	userRealm = testing.NewUserRealm(testutils.TestAddress("user"))
)

func TestKnownAccounts(t *testing.T) {
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewUserRealm(alice))
	func() {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/test"))
		uassert.Equal(t, 1, KnownAccounts())
	}()
}

func TestTotalSupply(t *testing.T) {
	uassert.Equal(t, INITIAL_MINT_AMOUNT, TotalSupply())
}

func TestBalanceOf(t *testing.T) {
	uassert.Equal(t, INITIAL_MINT_AMOUNT, BalanceOf(adminAddr))
}

func TestValidEmissionAmount(t *testing.T) {
	tests := []struct {
		name         string
		amount       int64
		shouldError  bool
		errorMessage string
	}{
		{
			name:         "should panic if emission amount is too large",
			amount:       MAXIMUM_SUPPLY,
			shouldError:  true,
			errorMessage: "[GNOSWAP-GNS-002] too many emission reward || too many emission amount: 1000000000000000",
		},
		{
			name:   "should not panic if emission amount is not too large",
			amount: 123,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validEmissionAmount(tt.amount)

			if tt.shouldError {
				uassert.Equal(t, tt.errorMessage, err.Error())
			} else {
				uassert.Equal(t, nil, err)
			}
		})
	}
}

func TestHandleLeftEmissionAmount(t *testing.T) {
	type testdata struct {
		name      string
		year      int64
		subAmount int64
		want      int64
	}

	tests := make([]testdata, 0, 24)

	for i := int64(1); i <= 12; i++ {
		tests = append(tests, testdata{
			name:      ufmt.Sprintf("handle left emission amount for year %d, non minted", i),
			year:      i,
			subAmount: 0,
			want:      GetHalvingYearMaxAmount(i),
		})

		tests = append(tests, testdata{
			name:      ufmt.Sprintf("handle left emission amount for year %d, minted", i),
			year:      i,
			subAmount: int64(123456),
			want:      GetHalvingYearMaxAmount(i) - int64(123456),
		})
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetEmissionState(t)

			if tt.subAmount > 0 {
				es := getEmissionState()
				es.subHalvingYearLeftAmount(tt.year, tt.subAmount)
			}

			actual := GetHalvingYearLeftAmount(tt.year)
			uassert.Equal(t, tt.want, actual,
				ufmt.Sprintf("year %d: expected left amount %d, got %d", tt.year, tt.want, actual))
		})
	}
}

func TestGetterSetter(t *testing.T) {
	t.Run("last minted timestamp", func(t *testing.T) {
		value := int64(1234567890)
		setLastMintedTimestamp(value)
		uassert.Equal(t, value, LastMintedTimestamp())
	})

	t.Run("left emission amount", func(t *testing.T) {
		value := int64(0)
		setLeftEmissionAmount(value)
		uassert.Equal(t, value, LeftEmissionAmount())
	})
}

func TestGrc20Methods(t *testing.T) {
	tests := []struct {
		name          string
		fn            func()
		shouldPanic   bool
		exceptionKind string // abort / panic
		panicMsg      string
	}{
		{
			name: "TotalSupply",
			fn: func() {
				uassert.Equal(t, INITIAL_MINT_AMOUNT, TotalSupply())
			},
		},
		{
			name: "BalanceOf(admin)",
			fn: func() {
				uassert.Equal(t, INITIAL_MINT_AMOUNT, BalanceOf(adminAddr))
			},
		},
		{
			name: "BalanceOf(alice)",
			fn: func() {
				uassert.Equal(t, int64(0), BalanceOf(alice))
			},
		},
		{
			name: "Allowance(admin, alice)",
			fn: func() {
				uassert.Equal(t, int64(0), Allowance(adminAddr, alice))
			},
		},
		{
			name: "MintGns success",
			fn: func() {
				testing.SetRealm(emissionRealm)
				MintGns(cross, adminAddr)
			},
		},
		{
			name: "MintGns without permission should panic",
			fn: func() {
				testing.SkipHeights(1) // Skip 1 block = 5 seconds pass
				MintGns(cross, adminAddr)
			},
			shouldPanic:   true,
			exceptionKind: "abort",
			panicMsg:      `unauthorized: caller g13ffa5r3mqfxu3s7ejl02scq9536wt6c2t789dm is not emission`,
		},
		{
			name: "Transfer success",
			fn: func() {
				testing.SetOriginCaller(adminAddr)
				testing.SetRealm(adminRealm)
				Transfer(cross, alice, int64(1))
			},
		},
		{
			name: "Transfer without enough balance should panic",
			fn: func() {
				testing.SetOriginCaller(alice)
				testing.SetRealm(testing.NewUserRealm(alice))
				Transfer(cross, bob, int64(1))
			},
			shouldPanic:   true,
			exceptionKind: "abort",
			panicMsg:      `insufficient balance`,
		},
		{
			name: "Transfer to self should panic",
			fn: func() {
				testing.SetOriginCaller(adminAddr)
				testing.SetRealm(adminRealm)
				Transfer(cross, adminAddr, int64(1))
			},
			shouldPanic:   true,
			exceptionKind: "abort",
			panicMsg:      `cannot send transfer to self`,
		},
		{
			name: "TransferFrom success",
			fn: func() {
				// approve first
				testing.SetRealm(adminRealm)
				Approve(cross, alice, int64(1))

				// alice transfer admin's balance to bob
				testing.SetOriginCaller(alice)
				testing.SetRealm(testing.NewUserRealm(alice))
				TransferFrom(cross, adminAddr, bob, int64(1))
			},
		},
		{
			name: "TransferFrom without enough allowance should panic",
			fn: func() {
				testing.SetRealm(adminRealm)
				Approve(cross, alice, int64(1))

				testing.SetOriginCaller(alice)
				testing.SetRealm(testing.NewUserRealm(alice))
				TransferFrom(cross, adminAddr, bob, int64(2))
			},
			shouldPanic:   true,
			exceptionKind: "abort",
			panicMsg:      `insufficient allowance`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetGnsTokenObject(t)

			if tt.shouldPanic {
				switch tt.exceptionKind {
				case "abort":
					uassert.AbortsContains(t, tt.panicMsg, tt.fn)
				case "panic":
					uassert.PanicsContains(t, tt.panicMsg, tt.fn)
				default:
					t.Fatalf("unknown exception kind: %s", tt.exceptionKind)
				}
			} else {
				uassert.NotPanics(t, func() { tt.fn() })
			}
		})
	}
}

func TestCalculateAmountToMint(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)
	startTimestamp := GetHalvingYearStartTimestamp(1)
	endTimestamp := GetHalvingYearEndTimestamp(12)

	tests := []struct {
		name               string
		inputFromTimestamp int64
		inputToTimestamp   int64
		expectedAmount     int64
	}{
		{
			name:               "calculate amount to mint by 1 second for same year(1st year)",
			inputFromTimestamp: startTimestamp,
			inputToTimestamp:   startTimestamp,
			expectedAmount:     7134703, // 225M / SECONDS_IN_YEAR
		},
		{
			name:               "calculate amount to mint by 1 second for same year(2nd year)",
			inputFromTimestamp: GetHalvingYearStartTimestamp(2),
			inputToTimestamp:   GetHalvingYearStartTimestamp(2),
			expectedAmount:     7134703, // 225M / SECONDS_IN_YEAR
		},
		{
			name:               "calculate amount to mint by 1 second for same year(7th year, after halving)",
			inputFromTimestamp: GetHalvingYearStartTimestamp(7),
			inputToTimestamp:   GetHalvingYearStartTimestamp(7),
			expectedAmount:     891837, // 112.5M / SECONDS_IN_YEAR
		},
		{
			name:               "calculate amount to mint by 2 seconds for same year(1st year)",
			inputFromTimestamp: startTimestamp,
			inputToTimestamp:   startTimestamp + 1,
			expectedAmount:     14269406,
		},
		{
			name:               "calculate amount to mint by 1st year's entire period - 1 second",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1),
			inputToTimestamp:   GetHalvingYearEndTimestamp(1) - 1,
			expectedAmount:     224_999_986_673_297, // almost 225M
		},
		{
			name:               "calculate amount to mint by 1st year's entire period",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1),
			inputToTimestamp:   GetHalvingYearEndTimestamp(1),
			expectedAmount:     225_000_000_000_000, // 225M
		},
		{
			name:               "calculate amount to mint by 2nd year's entire period",
			inputFromTimestamp: GetHalvingYearStartTimestamp(2),
			inputToTimestamp:   GetHalvingYearEndTimestamp(2),
			expectedAmount:     225_000_000_000_000, // 225M
		},
		{
			name:               "calculate amount to mint by 7th year's entire period",
			inputFromTimestamp: GetHalvingYearStartTimestamp(7),
			inputToTimestamp:   GetHalvingYearEndTimestamp(7),
			expectedAmount:     28_125_000_000_000, // 112.5M (halved)
		},
		{
			name:               "calculate amount to mint by 1st year's entire period and 2nd year's 1 second",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1),
			inputToTimestamp:   GetHalvingYearStartTimestamp(2),
			expectedAmount:     225_000_007_134_703, // 225M + 7134
		},
		{
			name:               "calculate amount to mint by entire period for 12 years",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1),
			inputToTimestamp:   GetHalvingYearEndTimestamp(12),
			expectedAmount:     900_000_000_000_000, // 900M total
		},
		{
			name:               "calculate amount to mint is zero amount by after emission end timestamp",
			inputFromTimestamp: GetHalvingYearEndTimestamp(12) + 1,
			inputToTimestamp:   GetHalvingYearEndTimestamp(12) + 10000,
			expectedAmount:     0,
		},
		{
			name:               "calculate amount to mint is zero amount by before emission start timestamp",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1) - 100,
			inputToTimestamp:   GetHalvingYearStartTimestamp(1) - 1,
			expectedAmount:     0,
		},
		// Edge cases
		{
			name:               "fromTimestamp greater than toTimestamp",
			inputFromTimestamp: startTimestamp + 1000,
			inputToTimestamp:   startTimestamp,
			expectedAmount:     0,
		},
		{
			name:               "fromTimestamp before start, toTimestamp after start",
			inputFromTimestamp: startTimestamp - 100,
			inputToTimestamp:   startTimestamp + 100,
			expectedAmount:     GetAmountPerSecondPerHalvingYear(1) * 101,
		},
		{
			name:               "spanning year 1 to year 3",
			inputFromTimestamp: GetHalvingYearStartTimestamp(1),
			inputToTimestamp:   GetHalvingYearEndTimestamp(3),
			expectedAmount:     GetHalvingAmountsPerYear(1) + GetHalvingAmountsPerYear(2) + GetHalvingAmountsPerYear(3),
		},
		{
			name:               "before start to after end (full emission)",
			inputFromTimestamp: startTimestamp - 1000,
			inputToTimestamp:   endTimestamp + 1000,
			expectedAmount:     MAX_EMISSION_AMOUNT,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			InitGnsTest(t)

			amount, err := calculateAmountToMint(getEmissionState(), tt.inputFromTimestamp, tt.inputToTimestamp)
			uassert.NoError(t, err)

			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestCalculateAmountToMintBoundary(t *testing.T) {
	t.Run("toTimestamp clamp to emission end", func(t *testing.T) {
		InitGnsTest(t)

		emissionEnd := GetHalvingYearEndTimestamp(12)
		year12Start := GetHalvingYearStartTimestamp(12)

		// Calculate amount for year 12 with toTimestamp at exactly emission end
		amountAtEnd, err := calculateAmountToMint(getEmissionState(), year12Start, emissionEnd)
		uassert.NoError(t, err)

		InitGnsTest(t)

		// Calculate amount for year 12 with toTimestamp after emission end (should be clamped)
		amountAfterEnd, err := calculateAmountToMint(getEmissionState(), year12Start, emissionEnd+1000)
		uassert.NoError(t, err)

		// Both should return the same amount (clamped to endTimestamp)
		uassert.Equal(t, amountAtEnd, amountAfterEnd)
		uassert.Equal(t, GetHalvingAmountsPerYear(12), amountAtEnd)
	})

	t.Run("year end last second vs second-to-last", func(t *testing.T) {
		InitGnsTest(t)

		year1Start := GetHalvingYearStartTimestamp(1)
		year1End := GetHalvingYearEndTimestamp(1)
		amountPerSecond := GetAmountPerSecondPerHalvingYear(1)

		// Amount up to second-to-last second of year 1
		amountSecondToLast, err := calculateAmountToMint(getEmissionState(), year1Start, year1End-1)
		uassert.NoError(t, err)

		InitGnsTest(t)

		// Amount up to last second of year 1 (includes leftover)
		amountLastSecond, err := calculateAmountToMint(getEmissionState(), year1Start, year1End)
		uassert.NoError(t, err)

		// Last second should add the leftover to reach exactly the year's max amount
		uassert.Equal(t, GetHalvingAmountsPerYear(1), amountLastSecond)

		// The difference should be more than just 1 second of emission (due to leftover)
		difference := amountLastSecond - amountSecondToLast
		uassert.True(t, difference > amountPerSecond,
			"last second should include leftover, not just 1 second of emission")
	})

	t.Run("fromTimestamp at emission start boundary", func(t *testing.T) {
		InitGnsTest(t)

		emissionStart := GetHalvingYearStartTimestamp(1)
		amountPerSecond := GetAmountPerSecondPerHalvingYear(1)

		// fromTimestamp exactly at emission start
		amountAtStart, err := calculateAmountToMint(getEmissionState(), emissionStart, emissionStart)
		uassert.NoError(t, err)
		uassert.Equal(t, amountPerSecond, amountAtStart)

		InitGnsTest(t)

		// fromTimestamp before emission start (should be clamped to start)
		amountBeforeStart, err := calculateAmountToMint(getEmissionState(), emissionStart-100, emissionStart)
		uassert.NoError(t, err)
		uassert.Equal(t, amountPerSecond, amountBeforeStart)
	})

	t.Run("year transition boundary", func(t *testing.T) {
		InitGnsTest(t)

		year1End := GetHalvingYearEndTimestamp(1)
		year2Start := GetHalvingYearStartTimestamp(2)

		// Verify year2Start = year1End + 1
		uassert.Equal(t, year1End+1, year2Start)

		// Calculate from last second of year 1 to first second of year 2
		amount, err := calculateAmountToMint(getEmissionState(), year1End, year2Start)
		uassert.NoError(t, err)

		// Should include: year 1's last second (with leftover) + year 2's first second
		year1AmountPerSecond := GetAmountPerSecondPerHalvingYear(1)
		year2AmountPerSecond := GetAmountPerSecondPerHalvingYear(2)

		// Year 1's last second includes leftover, Year 2's first second is just amountPerSecond
		// Total should be > year1AmountPerSecond + year2AmountPerSecond (due to leftover)
		minExpected := year1AmountPerSecond + year2AmountPerSecond
		uassert.True(t, amount > minExpected,
			"amount should include year 1's leftover")
	})
}

func TestMintGns_WithZeroLastMintedTimestamp(t *testing.T) {
	InitGnsTest(t)
	resetEmissionState(t)

	// Verify lastMintedTimestamp is initialized to 0
	uassert.Equal(t, int64(0), LastMintedTimestamp())

	// First mint with lastMintedTimestamp = 0
	// calculateAmountToMint(getEmissionState(), 0+1, currentTime) is called
	// Since fromTimestamp(1) < emissionState.startTimestamp, it gets adjusted to startTimestamp
	// Result: 1 second worth of emission (due to +1 in seconds calculation)
	testing.SetRealm(emissionRealm)
	currentTime := time.Now().Unix()
	firstMintAmount := MintGns(cross, adminAddr)

	uassert.Equal(t, int64(7134703), firstMintAmount)

	// Verify lastMintedTimestamp was updated to currentTime
	uassert.Equal(t, currentTime, LastMintedTimestamp())
}

func TestMintGns(t *testing.T) {
	tests := []struct {
		name                  string
		inputRealm            runtime.Realm
		inputSkipHeight       int64
		expectedMintedAmount1 int64
		expectedMintedAmount2 int64
		expectedHasAbort      bool
		expectedAbortMessage  string
	}{
		{
			name:                  "mint gns is success by emission realm",
			inputRealm:            emissionRealm,
			inputSkipHeight:       1,
			expectedMintedAmount1: 7134703,  // 1 second worth of emission (includes +1 in calculation)
			expectedMintedAmount2: 35673515, // 5 seconds worth of emission (7134703 * 5)
			expectedHasAbort:      false,
			expectedAbortMessage:  "",
		},
		{
			name:                  "mint gns is failed by caller is not emission realm",
			inputRealm:            testing.NewUserRealm(testutils.TestAddress("user")),
			inputSkipHeight:       1,
			expectedMintedAmount1: 0,
			expectedMintedAmount2: 0,
			expectedHasAbort:      true,
			expectedAbortMessage:  "unauthorized: caller g1w4ek2ujlta047h6lta047h6lta047h6lkvk347 is not emission",
		},
		{
			name:                  "mint gns is failed by not allowed to mint same timestamp",
			inputRealm:            emissionRealm,
			inputSkipHeight:       0,
			expectedMintedAmount1: 7134703, // 1 second worth of emission (includes +1 in calculation)
			expectedMintedAmount2: 0,       // same timestamp, returns 0
			expectedHasAbort:      false,
			expectedAbortMessage:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			InitGnsTest(t)
			resetEmissionState(t)

			var firstMintedAmount int64
			var secondMintedAmount int64

			mintGnsFn := func() {
				testing.SetRealm(tt.inputRealm)

				firstMintedAmount = MintGns(cross, adminAddr)
				testing.SkipHeights(tt.inputSkipHeight)
				secondMintedAmount = MintGns(cross, adminAddr)
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, mintGnsFn)
			} else {
				uassert.NotPanics(t, mintGnsFn)
			}

			// Validate individual minted amounts
			if !tt.expectedHasAbort {
				uassert.Equal(t, tt.expectedMintedAmount1, firstMintedAmount, "first mint should return the expected amount")
				uassert.Equal(t, tt.expectedMintedAmount2, secondMintedAmount, "second mint should return the expected amount")
			}
		})
	}
}

func TestMintGns_EdgeCases(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func()
		expectedMintedAmount int64
	}{
		{
			name: "returns zero when lastMintedTimestamp equals currentTime",
			setup: func() {
				InitGnsTest(t)
				resetEmissionState(t)
				// Set lastMintedTimestamp to current time
				setLastMintedTimestamp(time.Now().Unix())
			},
			expectedMintedAmount: 0,
		},
		{
			name: "returns zero when lastMintedTimestamp >= emissionEndTimestamp",
			setup: func() {
				InitGnsTest(t)
				resetEmissionState(t)
				// Set lastMintedTimestamp past emission end
				setLastMintedTimestamp(GetEmissionEndTimestamp() + 1)
			},
			expectedMintedAmount: 0,
		},
		{
			name: "mints correctly after skipping multiple blocks",
			setup: func() {
				InitGnsTest(t)
				resetEmissionState(t)
			},
			expectedMintedAmount: 7134703, // 1 second worth
		},
		{
			name: "updates MintedEmissionAmount correctly",
			setup: func() {
				InitGnsTest(t)
				resetEmissionState(t)
				uassert.Equal(t, int64(0), MintedEmissionAmount())
			},
			expectedMintedAmount: 7134703,
		},
		{
			name: "updates LeftEmissionAmount correctly",
			setup: func() {
				InitGnsTest(t)
				resetEmissionState(t)
				uassert.Equal(t, MAX_EMISSION_AMOUNT, LeftEmissionAmount())
			},
			expectedMintedAmount: 7134703,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			balanceBefore := BalanceOf(adminAddr)
			var mintedAmount int64
			uassert.NotPanics(t, func() {
				testing.SetRealm(emissionRealm)
				mintedAmount = MintGns(cross, adminAddr)
			})
			balanceAfter := BalanceOf(adminAddr)
			uassert.Equal(t, tt.expectedMintedAmount, mintedAmount)
			uassert.Equal(t, mintedAmount, balanceAfter-balanceBefore)
		})
	}
}

func TestMintGns_StateUpdates(t *testing.T) {
	tests := []struct {
		name          string
		validateState func(t *testing.T, mintedAmount int64)
	}{
		{
			name: "MintedEmissionAmount increases after mint",
			validateState: func(t *testing.T, mintedAmount int64) {
				uassert.Equal(t, mintedAmount, MintedEmissionAmount())
			},
		},
		{
			name: "LeftEmissionAmount decreases after mint",
			validateState: func(t *testing.T, mintedAmount int64) {
				uassert.Equal(t, MAX_EMISSION_AMOUNT-mintedAmount, LeftEmissionAmount())
			},
		},
		{
			name: "LastMintedTimestamp updates to current time",
			validateState: func(t *testing.T, mintedAmount int64) {
				uassert.Equal(t, time.Now().Unix(), LastMintedTimestamp())
			},
		},
		{
			name: "TotalSupply increases after mint",
			validateState: func(t *testing.T, mintedAmount int64) {
				uassert.Equal(t, INITIAL_MINT_AMOUNT+mintedAmount, TotalSupply())
			},
		},
		{
			name: "recipient balance increases after mint",
			validateState: func(t *testing.T, mintedAmount int64) {
				uassert.Equal(t, INITIAL_MINT_AMOUNT+mintedAmount, BalanceOf(adminAddr))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)
			InitGnsTest(t)

			balanceBefore := BalanceOf(adminAddr)

			var mintedAmount int64
			uassert.NotPanics(t, func() {
				testing.SetRealm(emissionRealm)
				mintedAmount = MintGns(cross, adminAddr)
			})

			balanceAfter := BalanceOf(adminAddr)

			uassert.Equal(t, mintedAmount, balanceAfter-balanceBefore)
			tt.validateState(t, mintedAmount)
		})
	}
}

func TestInitEmissionState(t *testing.T) {
	tests := []struct {
		name          string
		realm         runtime.Realm
		height        int64
		timestamp     int64
		shouldAbort   bool
		abortContains string
		validateState func(t *testing.T)
	}{
		{
			name:          "should abort when caller is not emission realm",
			realm:         userRealm,
			height:        100,
			timestamp:     1000,
			shouldAbort:   true,
			abortContains: "not emission",
		},
		{
			name:          "should abort when caller is admin realm",
			realm:         adminRealm,
			height:        100,
			timestamp:     1000,
			shouldAbort:   true,
			abortContains: "not emission",
		},
		{
			name:        "should succeed when caller is emission realm",
			realm:       emissionRealm,
			height:      100,
			timestamp:   1000,
			shouldAbort: false,
			validateState: func(t *testing.T) {
				uassert.True(t, IsEmissionInitialized())
				uassert.Equal(t, int64(100), GetEmissionStartHeight())
				uassert.Equal(t, int64(1000), GetEmissionStartTimestamp())
			},
		},
		{
			name:        "should initialize with zero height and timestamp",
			realm:       emissionRealm,
			height:      0,
			timestamp:   0,
			shouldAbort: false,
			validateState: func(t *testing.T) {
				// With height=0 and timestamp=0, isInitialized returns false
				uassert.False(t, IsEmissionInitialized())
				uassert.Equal(t, int64(0), GetEmissionStartHeight())
				uassert.Equal(t, int64(0), GetEmissionStartTimestamp())
			},
		},
		{
			name:        "should initialize with large timestamp",
			realm:       emissionRealm,
			height:      1000000,
			timestamp:   1700000000,
			shouldAbort: false,
			validateState: func(t *testing.T) {
				uassert.True(t, IsEmissionInitialized())
				uassert.Equal(t, int64(1000000), GetEmissionStartHeight())
				uassert.Equal(t, int64(1700000000), GetEmissionStartTimestamp())
				// Verify end timestamp calculation
				expectedEnd := int64(1700000000) + SECONDS_IN_YEAR*HALVING_END_YEAR - 1
				uassert.Equal(t, expectedEnd, GetEmissionEndTimestamp())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			if tt.shouldAbort {
				uassert.AbortsContains(t, tt.abortContains, func() {
					testing.SetRealm(tt.realm)
					InitEmissionState(cross, tt.height, tt.timestamp)
				})
			} else {
				uassert.NotPanics(t, func() {
					testing.SetRealm(tt.realm)
					InitEmissionState(cross, tt.height, tt.timestamp)
				})

				if tt.validateState != nil {
					tt.validateState(t)
				}
			}
		})
	}
}

func TestInitEmissionState_Reinitialize(t *testing.T) {
	resetObject(t)

	// First initialization
	uassert.NotPanics(t, func() {
		testing.SetRealm(emissionRealm)
		InitEmissionState(cross, 50, 500)
	})
	uassert.Equal(t, int64(50), GetEmissionStartHeight())
	uassert.Equal(t, int64(500), GetEmissionStartTimestamp())

	// Reinitialize with new values
	uassert.NotPanics(t, func() {
		testing.SetRealm(emissionRealm)
		InitEmissionState(cross, 200, 2000)
	})
	// Should be overwritten with new values
	uassert.Equal(t, int64(200), GetEmissionStartHeight())
	uassert.Equal(t, int64(2000), GetEmissionStartTimestamp())
}

func TestInitEmissionState_HalvingDataInitialization(t *testing.T) {
	tests := []struct {
		name          string
		timestamp     int64
		validateYear  int64
		expectedStart int64
		expectedEnd   int64
	}{
		{
			name:          "year 1 timestamps calculated correctly",
			timestamp:     1000,
			validateYear:  1,
			expectedStart: 1000,
			expectedEnd:   1000 + SECONDS_IN_YEAR - 1,
		},
		{
			name:          "year 6 timestamps calculated correctly",
			timestamp:     1000,
			validateYear:  6,
			expectedStart: 1000 + (SECONDS_IN_YEAR * 5),
			expectedEnd:   1000 + (SECONDS_IN_YEAR * 6) - 1,
		},
		{
			name:          "year 12 timestamps calculated correctly",
			timestamp:     1000,
			validateYear:  12,
			expectedStart: 1000 + (SECONDS_IN_YEAR * 11),
			expectedEnd:   1000 + (SECONDS_IN_YEAR * 12) - 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			uassert.NotPanics(t, func() {
				testing.SetRealm(emissionRealm)
				InitEmissionState(cross, 100, tt.timestamp)
			})

			actualStart := GetHalvingYearStartTimestamp(tt.validateYear)
			actualEnd := GetHalvingYearEndTimestamp(tt.validateYear)

			uassert.Equal(t, tt.expectedStart, actualStart)
			uassert.Equal(t, tt.expectedEnd, actualEnd)
		})
	}
}
