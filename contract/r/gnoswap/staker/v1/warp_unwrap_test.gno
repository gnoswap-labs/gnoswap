package v1

import (
	"errors"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoland/wugnot"
)

func TestWrap(t *testing.T) {
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Give caller wugnot and approve staker
			if tc.amount > 0 {
				ugnotFaucet(t, tc.callerAddr, 1_000)
				ugnotDeposit(t, tc.callerAddr, 1_000)
			}

			testing.SetRealm(testing.NewUserRealm(tc.callerAddr))
			wugnot.Approve(cross, tc.toAddr, tc.amount)

			beforeBalance := TokenBalance(t, wugnotPath, tc.toAddr)

			var err error
			func(cur realm) {
				testing.SetRealm(stakerRealm)
				err = wrapWithTransfer(tc.callerAddr, tc.toAddr, tc.amount)
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

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ugnotFaucet(t, stakerAddr, 1_000)
			ugnotDeposit(t, stakerAddr, 1_000)

			testing.SetRealm(stakerRealm)

			// unwrapWithTransfer now sends wugnot (not ugnot)
			beforeBalance := TokenBalance(t, wugnotPath, user2Addr)

			var err error
			func(cur realm) {
				testing.SetRealm(stakerRealm)
				err = unwrapWithTransfer(user2Addr, tc.amount)
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
