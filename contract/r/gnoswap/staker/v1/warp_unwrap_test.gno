package v1

import (
	"chain"
	"chain/banker"
	"errors"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
)

func TestWrap(t *testing.T) {
	user1Addr := testutils.TestAddress("user1")
	tests := []struct {
		name                  string
		callerAddr            address
		toAddr                address
		tokenPath             string
		amount                int64
		expectedBalanceChange int64
		expectedHasError      bool
		expectedError         error
	}{
		{
			name:                  "success by native token",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			tokenPath:             "ugnot",
			amount:                1000,
			expectedBalanceChange: 1000,
			expectedHasError:      false,
			expectedError:         nil,
		},
		{
			name:                  "success by grc20 token amount is 999",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			tokenPath:             wugnotPath,
			amount:                999,
			expectedBalanceChange: 999,
			expectedHasError:      false,
			expectedError:         nil,
		},
		{
			name:                  "success by token amount is 0",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			tokenPath:             wugnotPath,
			amount:                0,
			expectedBalanceChange: 0,
			expectedHasError:      false,
			expectedError:         nil,
		},
		{
			name:                  "failure by native token amount is 999",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			tokenPath:             "ugnot",
			amount:                999,
			expectedBalanceChange: 0,
			expectedHasError:      true,
			expectedError:         errors.New("[GNOSWAP-STAKER-006] can not wrapless than minimum amount || amount(999) < minimum(1000)"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			isNative := tc.tokenPath == "ugnot"
			testing.SetRealm(testing.NewUserRealm(tc.callerAddr))

			if isNative {
				ugnotFaucet(t, tc.callerAddr, 1_000)

				testing.SetOriginSend(chain.Coins{{ugnotPath, tc.amount}})
				banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
				banker_.SendCoins(tc.callerAddr, tc.toAddr, chain.Coins{{ugnotPath, tc.amount}})
			} else {
				ugnotFaucet(t, tc.callerAddr, 1_000)
				ugnotDeposit(t, tc.callerAddr, 1_000)
			}

			testing.SetRealm(testing.NewUserRealm(tc.callerAddr))
			wugnot.Approve(cross, tc.toAddr, tc.amount)

			beforeBalance := TokenBalance(t, wugnotPath, tc.toAddr)

			var err error
			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(tc.toAddr))
				if isNative {
					err = wrapWithTransfer(tc.toAddr, tc.amount)
				} else {
					err = common.TransferFrom(cross, tc.tokenPath, tc.callerAddr, tc.toAddr, tc.amount)
				}
			}(cross)

			afterBalance := TokenBalance(t, wugnotPath, tc.toAddr)

			if tc.expectedHasError {
				uassert.ErrorIs(t, tc.expectedError, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedBalanceChange, afterBalance-beforeBalance)
			}
		})
	}
}

func TestUnwrap(t *testing.T) {
	user2Addr := testutils.TestAddress("user2")
	tests := []struct {
		name                  string
		amount                int64
		unwrap                bool
		expectedBalanceChange int64
		expectedHasPanic      bool
		expectedPanicMessage  string
	}{
		{
			name:                  "Failure - Zero amount",
			amount:                0,
			unwrap:                true,
			expectedBalanceChange: 0,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Valid amount",
			amount:                1_000,
			unwrap:                true,
			expectedBalanceChange: 1_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Valid amount with unwrap",
			amount:                1_000,
			unwrap:                true,
			expectedBalanceChange: 1_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ugnotFaucet(t, stakerAddr, 1_000)
			ugnotDeposit(t, stakerAddr, 1_000)

			testing.SetRealm(stakerRealm)

			beforeBalance := TokenBalance(t, wugnotPath, user2Addr)
			if tc.unwrap {
				banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
				beforeBalance = banker_.GetCoins(user2Addr).AmountOf("ugnot")
			}

			var err error
			func(cur realm) {
				testing.SetRealm(testing.NewUserRealm(stakerAddr))
				err = unwrapWithTransfer(user2Addr, tc.amount)
			}(cross)

			afterBalance := TokenBalance(t, wugnotPath, user2Addr)
			if tc.unwrap {
				banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
				afterBalance = banker_.GetCoins(user2Addr).AmountOf("ugnot")
			}

			if tc.expectedHasPanic {
				uassert.ErrorIs(t, errors.New(tc.expectedPanicMessage), err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedBalanceChange, afterBalance-beforeBalance)
			}
		})
	}
}
