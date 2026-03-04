package v1

import (
	"chain"
	"errors"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoland/wugnot"
)

func TestTransferWugnotFrom(t *testing.T) {
	user1Addr := testutils.TestAddress("user1")
	tests := []struct {
		name                  string
		callerAddr            address
		toAddr                address
		amount                int64
		expectedBalanceChange int64
		expectedHasError      bool
		expectedError         error
	}{
		{
			name:                  "success - transfer wugnot from user to staker",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			amount:                1000,
			expectedBalanceChange: 1000,
			expectedHasError:      false,
			expectedError:         nil,
		},
		{
			name:                  "success - amount 999",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			amount:                999,
			expectedBalanceChange: 999,
			expectedHasError:      false,
			expectedError:         nil,
		},
		{
			name:                  "success - zero amount",
			callerAddr:            user1Addr,
			toAddr:                stakerAddr,
			amount:                0,
			expectedBalanceChange: 0,
			expectedHasError:      false,
			expectedError:         nil,
		},
	}

	// Deposit wugnot BEFORE the for loop to avoid "invalid non-origin call"
	// from wugnot.Deposit(cross) inside t.Run subtests.
	// Total needed: 2 subtests * 1000 = 2000
	{
		totalDeposit := int64(2_000)
		ugnotFaucet(t, user1Addr, totalDeposit)
		ugnotDepositPrepare(t, user1Addr, totalDeposit)
		testing.SetRealm(testing.NewUserRealm(user1Addr))
		testing.SetOriginSend(chain.Coins{{"ugnot", totalDeposit}})
		wugnot.Deposit(cross)
		testing.SetOriginSend(chain.Coins{})
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetRealm(testing.NewUserRealm(tc.callerAddr))
			wugnot.Approve(cross, tc.toAddr, tc.amount)

			beforeBalance := TokenBalance(t, wugnotPath, tc.toAddr)

			var err error
			func(cur realm) {
				testing.SetRealm(stakerRealm)
				err = transferWugnotFrom(tc.callerAddr, tc.toAddr, tc.amount)
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

func TestTransferWugnot(t *testing.T) {
	user2Addr := testutils.TestAddress("user2")
	tests := []struct {
		name                  string
		amount                int64
		expectedBalanceChange int64
		expectedHasPanic      bool
		expectedPanicMessage  string
	}{
		{
			name:                  "Success - Zero amount",
			amount:                0,
			expectedBalanceChange: 0,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
		{
			name:                  "Success - Valid amount",
			amount:                1_000,
			expectedBalanceChange: 1_000,
			expectedHasPanic:      false,
			expectedPanicMessage:  "",
		},
	}

	// Deposit wugnot BEFORE the for loop to avoid "invalid non-origin call"
	// from wugnot.Deposit(cross) inside t.Run subtests.
	// Total needed: 2 subtests * 1000 = 2000
	{
		totalDeposit := int64(2_000)
		ugnotFaucet(t, stakerAddr, totalDeposit)
		ugnotDepositPrepare(t, stakerAddr, totalDeposit)
		testing.SetRealm(testing.NewUserRealm(stakerAddr))
		testing.SetOriginSend(chain.Coins{{"ugnot", totalDeposit}})
		wugnot.Deposit(cross)
		testing.SetOriginSend(chain.Coins{})
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			testing.SetRealm(stakerRealm)

			// transferWugnot sends wugnot (not ugnot)
			beforeBalance := TokenBalance(t, wugnotPath, user2Addr)

			var err error
			func(cur realm) {
				testing.SetRealm(stakerRealm)
				err = transferWugnot(user2Addr, tc.amount)
			}(cross)

			afterBalance := TokenBalance(t, wugnotPath, user2Addr)

			if tc.expectedHasPanic {
				uassert.ErrorIs(t, errors.New(tc.expectedPanicMessage), err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tc.expectedBalanceChange, afterBalance-beforeBalance)
			}
		})
	}
}
