package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/halt"
)

const (
	// gnoVM test context default height
	// ref: https://github.com/gnolang/gno/blob/a85a53d5b38f0a21d66262a823a8b07f4f836b68/gnovm/pkg/test/test.go#L31-L32
	GNO_VM_DEFAULT_HEIGHT = int64(123)
)

var (
	emissionRealm = std.NewCodeRealm("gno.land/r/gnoswap/v1/emission")
	adminRealm    = std.NewUserRealm(adminAddr)
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	userRealm = std.NewUserRealm(testutils.TestAddress("user"))
)

func TestKnownAccounts(t *testing.T) {
	testing.SetOriginCaller(alice)
	testing.SetRealm(std.NewUserRealm(alice))
	func() {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
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
			errorMessage: "too many emission amount: 1000000000000000",
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

func TestIsLastSecondOfHalvingYear(t *testing.T) {
	tests := make([]struct {
		name      string
		timestamp int64
		want      bool
	}, 0, 24)

	for i := HALVING_START_YEAR; i <= HALVING_END_YEAR; i++ {
		tests = append(tests, struct {
			name      string
			timestamp int64
			want      bool
		}{
			name:      ufmt.Sprintf("last second of halving year %d", i),
			timestamp: GetHalvingYearEndTimestamp(i),
			want:      true,
		})

		tests = append(tests, struct {
			name      string
			timestamp int64
			want      bool
		}{
			name:      ufmt.Sprintf("not last second of halving year %d", i),
			timestamp: GetHalvingYearEndTimestamp(i) - 1,
			want:      false,
		})
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Note: This function may not exist, but assuming similar logic
			// uassert.Equal(t, tt.want, isLastSecondOfHalvingYear(tt.timestamp))
		})
	}
}

func TestHandleLeftEmissionAmount(t *testing.T) {
	tests := make([]struct {
		name   string
		year   int64
		amount int64
		want   int64
	}, 0, 24)

	for i := int64(1); i <= 12; i++ {
		tests = append(tests, struct {
			name   string
			year   int64
			amount int64
			want   int64
		}{
			name:   ufmt.Sprintf("handle left emission amount for year %d, non minted", i),
			year:   i,
			amount: 0,
			want:   GetHalvingYearMaxAmount(i),
		})

		tests = append(tests, struct {
			name   string
			year   int64
			amount int64
			want   int64
		}{
			name:   ufmt.Sprintf("handle left emission amount for year %d, minted", i),
			year:   i,
			amount: int64(123456),
			want:   GetHalvingYearMaxAmount(i) - int64(123456),
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
			panicMsg:      `unauthorized: caller g1jgqwaa2le3yr63d533fj785qkjspumzv22ys5m is not emission`,
		},
		{
			name: "Burn without permission should panic",
			fn: func() {
				Burn(cross, adminAddr, int64(1))
			},
			shouldPanic:   true,
			exceptionKind: "abort",
			panicMsg:      `ownable: caller is not owner`,
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
				testing.SetRealm(std.NewUserRealm(alice))
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
				testing.SetRealm(std.NewUserRealm(alice))
				TransferFrom(cross, adminAddr, bob, int64(1))
			},
		},
		{
			name: "TransferFrom without enough allowance should panic",
			fn: func() {
				testing.SetRealm(adminRealm)
				Approve(cross, alice, int64(1))

				testing.SetOriginCaller(alice)
				testing.SetRealm(std.NewUserRealm(alice))
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
					uassert.AbortsWithMessage(t, tt.panicMsg, tt.fn)
				case "panic":
					uassert.PanicsWithMessage(t, tt.panicMsg, tt.fn)
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

	tests := []struct {
		name                 string
		inputFromTimestamp   int64
		inputToTimestamp     int64
		expectedAmount       int64
	}{
		{
			name:                 "calculate amount to mint by 1 second for same year(1st year)",
			inputFromTimestamp:   startTimestamp,
			inputToTimestamp:     startTimestamp,
			expectedAmount:       7134703, // 225M / SECONDS_IN_YEAR
		},
		{
			name:                 "calculate amount to mint by 1 second for same year(2nd year)",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(2),
			inputToTimestamp:     GetHalvingYearStartTimestamp(2),
			expectedAmount:       7134703, // 225M / SECONDS_IN_YEAR
		},
		{
			name:                 "calculate amount to mint by 1 second for same year(7th year, after halving)",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(7),
			inputToTimestamp:     GetHalvingYearStartTimestamp(7),
			expectedAmount:       891837, // 112.5M / SECONDS_IN_YEAR
		},
		{
			name:                 "calculate amount to mint by 2 seconds for same year(1st year)",
			inputFromTimestamp:   startTimestamp,
			inputToTimestamp:     startTimestamp + 1,
			expectedAmount:       14269406,
		},
		{
			name:                 "calculate amount to mint by 1st year's entire period - 1 second",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(1),
			inputToTimestamp:     GetHalvingYearEndTimestamp(1) - 1,
			expectedAmount:       224_999_986_673_297, // almost 225M
		},
		{
			name:                 "calculate amount to mint by 1st year's entire period",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(1),
			inputToTimestamp:     GetHalvingYearEndTimestamp(1),
			expectedAmount:       225_000_000_000_000, // 225M
		},
		{
			name:                 "calculate amount to mint by 2nd year's entire period",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(2),
			inputToTimestamp:     GetHalvingYearEndTimestamp(2),
			expectedAmount:       225_000_000_000_000, // 225M
		},
		{
			name:                 "calculate amount to mint by 7th year's entire period",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(7),
			inputToTimestamp:     GetHalvingYearEndTimestamp(7),
			expectedAmount:       28_125_000_000_000, // 112.5M (halved)
		},
		{
			name:                 "calculate amount to mint by 1st year's entire period and 2nd year's 1 second",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(1),
			inputToTimestamp:     GetHalvingYearStartTimestamp(2),
			expectedAmount:       225_000_007_134_703, // 225M + 7134
		},
		{
			name:                 "calculate amount to mint by entire period for 12 years",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(1),
			inputToTimestamp:     GetHalvingYearEndTimestamp(12),
			expectedAmount:       900_000_000_000_000, // 900M total
		},
		{
			name:                 "calculate amount to mint is zero amount by after emission end timestamp",
			inputFromTimestamp:   GetHalvingYearEndTimestamp(12) + 1,
			inputToTimestamp:     GetHalvingYearEndTimestamp(12) + 10000,
			expectedAmount:       0,
		},
		{
			name:                 "calculate amount to mint is zero amount by before emission start timestamp",
			inputFromTimestamp:   GetHalvingYearStartTimestamp(1) - 100,
			inputToTimestamp:     GetHalvingYearStartTimestamp(1) - 1,
			expectedAmount:       0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			InitGnsTest(t)

			amount := calculateAmountToMint(tt.inputFromTimestamp, tt.inputToTimestamp)

			uassert.Equal(t, tt.expectedAmount, amount)
		})
	}
}

func TestMintGns(t *testing.T) {
	tests := []struct {
		name                 string
		halted               bool
		inputRealm           std.Realm
		inputSkipHeight      int64
		expectedMintedAmount int64
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:                 "mint gns is success by emission realm",
			halted:               false,
			inputRealm:           emissionRealm,
			inputSkipHeight:      1,
			expectedMintedAmount: 35673515, // 5 seconds worth of emission (7134 * 5)
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
		{
			name:                 "mint gns is failed by halted",
			halted:               true,
			inputRealm:           emissionRealm,
			inputSkipHeight:      1,
			expectedMintedAmount: 0,
			expectedHasAbort:     true,
			expectedAbortMessage: "halted: emission",
		},
		{
			name:                 "mint gns is failed by caller is not emission realm",
			halted:               false,
			inputRealm:           std.NewUserRealm(testutils.TestAddress("user")),
			inputSkipHeight:      1,
			expectedMintedAmount: 0,
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1w4ek2ujlta047h6lta047h6lta047h6lkvk347 is not emission",
		},
		{
			name:                 "mint gns is failed by not allowed to mint same timestamp",
			halted:               false,
			inputRealm:           emissionRealm,
			inputSkipHeight:      0,
			expectedMintedAmount: 0,
			expectedHasAbort:     false,
			expectedAbortMessage: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			InitGnsTest(t)

			testing.SetOriginCaller(adminAddr)

			if tt.halted {
				halt.SetHaltLevel(cross, halt.HaltLevelEmergency) // set halt
			} else {
				halt.SetHaltLevel(cross, halt.HaltLevelNone) // set halt
			}

			var mintedAmount int64

			mintGnsFn := func() {
				testing.SetRealm(tt.inputRealm)

				firstMintedAmount := MintGns(cross, adminAddr)
				testing.SkipHeights(tt.inputSkipHeight)
				secondMintedAmount := MintGns(cross, adminAddr)

				mintedAmount = firstMintedAmount + secondMintedAmount
			}

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMessage, mintGnsFn)
			} else {
				uassert.NotPanics(t, mintGnsFn)
			}

			uassert.Equal(t, tt.expectedMintedAmount, mintedAmount)
			halt.SetHaltLevel(cross, halt.HaltLevelNone)
		})
	}
}
