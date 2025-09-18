package staker

import (
	"errors"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoland/wugnot"
)

func TestWrap(t *testing.T) {
	user2Addr := testutils.TestAddress("user2")
	tests := []struct {
		name                  string
		amount                int64
		expectedBalanceChange int64
		expectedHasPanic      bool
		expectedPanicMessage  string
	}{
		{
			name:                  "Success - Wrap exactly minimum",
			amount:                UGNOT_MIN_DEPOSIT_TO_WRAP,
			expectedBalanceChange: UGNOT_MIN_DEPOSIT_TO_WRAP,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Wrap more than minimum",
			amount:                UGNOT_MIN_DEPOSIT_TO_WRAP + 1,
			expectedBalanceChange: UGNOT_MIN_DEPOSIT_TO_WRAP + 1,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Failure - Wrap zero",
			amount:                0,
			expectedBalanceChange: 0,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Failure - Wrap below minimum",
			amount:                UGNOT_MIN_DEPOSIT_TO_WRAP - 1,
			expectedBalanceChange: 0,
			expectedHasPanic:      true,
			expectedPanicMessage:  "[GNOSWAP-STAKER-006] can not wrapless than minimum amount || amount(999) < minimum(1000)",
		},
		{
			name:                  "Failure - Wrap negative amount",
			amount:                -1,
			expectedBalanceChange: 0,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Failure - Insufficient UGNOT sent",
			amount:                UGNOT_MIN_DEPOSIT_TO_WRAP,
			expectedBalanceChange: 0,
			expectedHasPanic:      true,
			expectedPanicMessage:  "invalid input data", // partial match
		},
		{
			name:                  "Failure - More UGNOT sent than amount",
			amount:                UGNOT_MIN_DEPOSIT_TO_WRAP,
			expectedBalanceChange: 0,
			expectedHasPanic:      true,
			expectedPanicMessage:  "invalid input data", // partial match
		},
		{
			name:                  "Success - Wrap large amount",
			amount:                10_000_000,
			expectedBalanceChange: 10_000_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Wrap to different user",
			amount:                5_000,
			expectedBalanceChange: 5_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Wrap to staker address",
			amount:                3_000,
			expectedBalanceChange: 3_000, // Balance will increase
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			beforeBalance := TokenBalance(t, wugnotPath, user2Addr)

			var err error
			var coins std.Coins

			// Setup coins based on test case
			if tt.name == "Failure - Insufficient UGNOT sent" {
				coins = std.Coins{{Denom: "ugnot", Amount: 0}}
			} else if tt.name == "Failure - More UGNOT sent than amount" {
				coins = std.Coins{{Denom: "ugnot", Amount: 2000}}
			} else {
				coins = std.Coins{{Denom: "ugnot", Amount: tt.amount}}
			}

			toAddr := user2Addr
			if tt.name == "Success - Wrap to staker address" {
				toAddr = stakerAddr
				beforeBalance = TokenBalance(t, wugnotPath, stakerAddr)
			}

			func(cur realm) {
				// Issue coins to staker for testing
				if tt.amount > 0 && tt.name != "Failure - Insufficient UGNOT sent" {
					testing.IssueCoins(stakerAddr, coins)
				}

				testing.SetOriginCaller(stakerAddr)
				testing.SetOriginSend(coins)
				testing.SetRealm(std.NewUserRealm(stakerAddr))
				err = wrapWithTransfer(toAddr, tt.amount)
			}(cross)

			afterBalance := TokenBalance(t, wugnotPath, user2Addr)
			if tt.name == "Success - Wrap to staker address" {
				afterBalance = TokenBalance(t, wugnotPath, stakerAddr)
			}

			if tt.expectedHasPanic {
				if tt.name == "Failure - Insufficient UGNOT sent" || tt.name == "Failure - More UGNOT sent than amount" {
					// For these cases, just check if error contains the key message
					uassert.ErrorContains(t, err, tt.expectedPanicMessage)
				} else {
					uassert.ErrorIs(t, errors.New(tt.expectedPanicMessage), err)
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedBalanceChange, afterBalance-beforeBalance)
			}
		})
	}
}

func TestUnwrap(t *testing.T) {
	user2Addr := testutils.TestAddress("user2")
	tests := []struct {
		name                  string
		tokenPath             string
		amount                int64
		unwrap                bool
		expectedBalanceChange int64
		expectedHasPanic      bool
		expectedPanicMessage  string
	}{
		{
			name:                  "Success - Zero amount WUGNOT",
			tokenPath:             WUGNOT_PATH,
			amount:                0,
			unwrap:                true,
			expectedBalanceChange: 0,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Valid amount WUGNOT",
			tokenPath:             WUGNOT_PATH,
			amount:                1_000,
			unwrap:                true,
			expectedBalanceChange: 1_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Failure - Non-WUGNOT token (GNS)",
			tokenPath:             "gno.land/r/gnoswap/gns",
			amount:                1_000,
			unwrap:                true,
			expectedBalanceChange: 0,
			expectedHasPanic:      true,
			expectedPanicMessage:  "cannot unwrap non-WUGNOT token: gno.land/r/gnoswap/gns",
		},
		{
			name:                  "Failure - Non-WUGNOT token (BAR)",
			tokenPath:             "gno.land/r/onbloc/bar",
			amount:                1_000,
			unwrap:                true,
			expectedBalanceChange: 0,
			expectedHasPanic:      true,
			expectedPanicMessage:  "cannot unwrap non-WUGNOT token: gno.land/r/onbloc/bar",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ugnotFaucet(t, stakerAddr, 1_000)
			ugnotDeposit(t, stakerAddr, 1_000)

			testing.SetRealm(stakerRealm)

			beforeBalance := TokenBalance(t, wugnotPath, user2Addr)
			if tt.unwrap {
				banker := std.NewBanker(std.BankerTypeRealmSend)
				beforeBalance = banker.GetCoins(user2Addr).AmountOf("ugnot")
			}

			testing.SetRealm(std.NewUserRealm(stakerAddr))
			err := unwrapWithTransfer(user2Addr, tt.tokenPath, tt.amount)

			afterBalance := TokenBalance(t, wugnotPath, user2Addr)
			if tt.unwrap {
				banker := std.NewBanker(std.BankerTypeRealmSend)
				afterBalance = banker.GetCoins(user2Addr).AmountOf("ugnot")
			}

			if tt.expectedHasPanic {
				uassert.ErrorContains(t, err, tt.expectedPanicMessage)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedBalanceChange, afterBalance-beforeBalance)
			}
		})
	}
}

func TestUnwrapWithTransferFrom(t *testing.T) {
	user1Addr := testutils.TestAddress("user1")
	user2Addr := testutils.TestAddress("user2")

	tests := []struct {
		name                 string
		tokenPath            string
		amount               int64
		setupFunc            func()
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:      "Success - Valid WUGNOT transfer and unwrap",
			tokenPath: WUGNOT_PATH,
			amount:    1_000,
			setupFunc: func() {
				// Give user1 WUGNOT and approve staker
				ugnotFaucet(t, user1Addr, 1_000)
				testing.SetRealm(std.NewUserRealm(user1Addr))
				ugnotDeposit(t, user1Addr, 1_000)
				wugnot.Approve(cross, stakerAddr, 1_000)
			},
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Success - Zero amount",
			tokenPath:            WUGNOT_PATH,
			amount:               0,
			setupFunc:            func() {},
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "Failure - Non-WUGNOT token",
			tokenPath:            "gno.land/r/gnoswap/gns",
			amount:               1_000,
			setupFunc:            func() {},
			expectedHasPanic:     true,
			expectedPanicMessage: "cannot unwrap non-WUGNOT token: gno.land/r/gnoswap/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setupFunc()

			// Get initial balance
			banker := std.NewBanker(std.BankerTypeRealmSend)
			beforeBalance := banker.GetCoins(user2Addr).AmountOf("ugnot")

			// Execute unwrapWithTransferFrom
			testing.SetRealm(std.NewUserRealm(stakerAddr))
			err := unwrapWithTransferFrom(user1Addr, user2Addr, tt.tokenPath, tt.amount)

			if tt.expectedHasPanic {
				uassert.ErrorContains(t, err, tt.expectedPanicMessage)
			} else {
				uassert.NoError(t, err)

				// Verify balance change for successful cases
				if tt.amount > 0 {
					afterBalance := banker.GetCoins(user2Addr).AmountOf("ugnot")
					uassert.Equal(t, tt.amount, afterBalance-beforeBalance)
				}
			}
		})
	}
}
