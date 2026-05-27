package community_pool

import (
	"chain/runtime"
	"math"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/rbac" // initialize rbac package
)

var (
	adminAddr  = rbac.DefaultRoleAddresses[prabc.ROLE_ADMIN]
	adminRealm = testing.NewUserRealm(adminAddr)

	communityPoolAddr = rbac.DefaultRoleAddresses[prabc.ROLE_COMMUNITY_POOL]

	gnsPath  = "gno.land/r/gnoswap/gns"
	govRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance")

	dummyCaller   = testing.NewUserRealm(testutils.TestAddress("dummyCaller"))
	dummyReceiver = testutils.TestAddress("dummyReceiver")
)

func resetCommunityPoolState(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	gns.Transfer(cross(cur), communityPoolAddr, 10_000)
}

func TestCommunityPool_TransferToken(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		setup       func(cur realm)
		caller      runtime.Realm
		tokenPath   string
		to          address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic if halted with complete level",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)
			},
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "halted: withdraw",
		},
		{
			name: "panic if halted with safe mode (withdraw blocked only)",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelSafeMode)
			},
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "halted: withdraw",
		},
		{
			name: "panic if caller is not admin or governance",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
			},
			caller:      dummyCaller,
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "unauthorized: caller g1v36k6mtegdskcmr9wf047h6lta047h6ljmnks7 is not admin or governance",
		},
		{
			name: "success transfer with enough balance",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    10,
		},
		{
			name: "admin can transfer community pool token",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1,
		},
		{
			name: "governance can transfer community pool token",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:    govRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1,
		},
		{
			name: "success transfer zero amount",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    0,
		},
		{
			name: "success transfer exact balance",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    10_000,
		},
		{
			name: "panic with negative amount",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:      adminRealm,
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      -100,
			shouldPanic: true,
			panicMsg:    "invalid amount",
		},
		{
			name: "panic with insufficient balance",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:      adminRealm,
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      math.MaxInt64,
			shouldPanic: true,
			panicMsg:    "insufficient balance",
		},
		{
			name: "panic with empty token path",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:      adminRealm,
			tokenPath:   "",
			to:          dummyReceiver,
			amount:      100,
			shouldPanic: true,
			panicMsg:    "unknown token",
		},
		{
			name: "panic with unregistered token path",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:      adminRealm,
			tokenPath:   "gno.land/r/demo/not_registered",
			to:          dummyReceiver,
			amount:      100,
			shouldPanic: true,
			panicMsg:    "unknown token",
		},
		{
			name: "panic with empty to address",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross(cur), communityPoolAddr, 10_000)
			},
			caller:      adminRealm,
			tokenPath:   gnsPath,
			to:          address(""),
			amount:      100,
			shouldPanic: true,
			panicMsg:    "invalid address",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {

			resetCommunityPoolState(cur, t)

			if tt.setup != nil {
				tt.setup(cur)
			}

			if tt.caller != (runtime.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					TransferToken(cross(cur), tt.tokenPath, tt.to, tt.amount)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(tt.to)
				TransferToken(cross(cur), tt.tokenPath, tt.to, tt.amount)
				receiverNewBalance := gns.BalanceOf(tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}

func TestCommunityPool_GetBalanceOf(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		setup           func(cur realm)
		tokenPath       string
		expectedBalance int64
		shouldAbort     bool
		panicMsg        string
	}{
		{
			name: "returns zero when pool has no tokens",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				// transfer all tokens from community pool to admin first
				currentBalance := gns.BalanceOf(communityPoolAddr)
				if currentBalance > 0 {
					TransferToken(cross(cur), gnsPath, adminAddr, currentBalance)
				}
			},
			tokenPath:       gnsPath,
			expectedBalance: 0,
		},
		{
			name: "returns correct balance after transfer to pool",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				// clear pool first
				currentBalance := gns.BalanceOf(communityPoolAddr)
				if currentBalance > 0 {
					TransferToken(cross(cur), gnsPath, adminAddr, currentBalance)
				}
				// transfer tokens to pool
				gns.Transfer(cross(cur), communityPoolAddr, 5_000)
			},
			tokenPath:       gnsPath,
			expectedBalance: 5_000,
		},
		{
			name: "returns updated balance after multiple transfers",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
				// clear pool first
				currentBalance := gns.BalanceOf(communityPoolAddr)
				if currentBalance > 0 {
					TransferToken(cross(cur), gnsPath, adminAddr, currentBalance)
				}
				// transfer tokens to pool multiple times
				gns.Transfer(cross(cur), communityPoolAddr, 1_000)
				gns.Transfer(cross(cur), communityPoolAddr, 2_000)
				gns.Transfer(cross(cur), communityPoolAddr, 3_000)
			},
			tokenPath:       gnsPath,
			expectedBalance: 6_000,
		},
		{
			name: "panics with unregistered token path",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
			},
			tokenPath:   "gno.land/r/demo/unregistered_token",
			shouldAbort: true,
			panicMsg:    "unknown token",
		},
		{
			name: "panics with empty token path",
			setup: func(cur realm) {
				testing.SetRealm(adminRealm)
			},
			tokenPath:   "",
			shouldAbort: true,
			panicMsg:    "unknown token",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			if tt.setup != nil {
				tt.setup(cur)
			}

			if tt.shouldAbort {
				uassert.AbortsContains(t, cur, tt.panicMsg, func() {
					GetBalanceOf(tt.tokenPath)
				})
			} else {
				balance := GetBalanceOf(tt.tokenPath)
				uassert.Equal(t, tt.expectedBalance, balance)
			}
		})
	}
}
