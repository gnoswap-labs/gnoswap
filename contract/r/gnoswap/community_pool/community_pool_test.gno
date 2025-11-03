package community_pool

import (
	"chain/runtime"
	"math"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

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

func resetCommunityPoolState(t *testing.T) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelNone)
	gns.Transfer(cross, communityPoolAddr, 10_000)
}

func TestCommunityPool_TransferToken(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		caller      runtime.Realm
		tokenPath   string
		to          address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic if halted with complete level",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
			},
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "halted: community_pool",
		},
		{
			name: "panic if halted with safe mode (withdraw blocked)",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
			},
			caller:      adminRealm,
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "halted: withdraw",
		},
		{
			name: "panic if caller is not admin or governance",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
				testing.SetRealm(dummyCaller)
			},
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "unauthorized: caller g13lpjmjhl2du7whed3wxe4n5508txxja6ezxeg7 is not admin or governance",
		},
		{
			name: "success transfer with enough balance",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    10,
		},
		{
			name: "admin can transfer community pool token",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1,
		},
		{
			name: "governance can transfer community pool token",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			caller:    govRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1,
		},
		{
			name: "success transfer zero amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    0,
		},
		{
			name: "panic with negative amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
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
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
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
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
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
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
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
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
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
		t.Run(tt.name, func(t *testing.T) {
			resetCommunityPoolState(t)

			if tt.setup != nil {
				tt.setup()
			}

			if tt.caller != (runtime.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					TransferToken(cross, tt.tokenPath, tt.to, tt.amount)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(tt.to)
				TransferToken(cross, tt.tokenPath, tt.to, tt.amount)
				receiverNewBalance := gns.BalanceOf(tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}

func TestCommunityPool_transferToken(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		tokenPath   string
		to          address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "success transfer with valid parameters",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1000,
		},
		{
			name: "success transfer zero amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    0,
		},
		{
			name: "success transfer with max valid amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    10_000,
		},
		{
			name: "success transfer minimum amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath: gnsPath,
			to:        dummyReceiver,
			amount:    1,
		},
		{
			name: "panic with negative amount",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath:   gnsPath,
			to:          dummyReceiver,
			amount:      -100,
			shouldPanic: true,
			panicMsg:    "invalid amount",
		},
		{
			name: "panic with empty token path",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath:   "",
			to:          dummyReceiver,
			amount:      100,
			shouldPanic: true,
			panicMsg:    "unknown token",
		},
		{
			name: "panic with unregistered token path",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath:   "gno.land/r/demo/not_registered",
			to:          dummyReceiver,
			amount:      100,
			shouldPanic: true,
			panicMsg:    "unknown token",
		},
		{
			name: "panic with empty to address",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			tokenPath:   gnsPath,
			to:          address(""),
			amount:      100,
			shouldPanic: true,
			panicMsg:    "invalid address",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetCommunityPoolState(t)

			if tt.setup != nil {
				tt.setup()
			}

			// Set realm to community pool for the transfer
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/community_pool"))

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					transferToken(tt.tokenPath, tt.to, tt.amount)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(tt.to)
				err := transferToken(tt.tokenPath, tt.to, tt.amount)
				uassert.NoError(t, err)
				receiverNewBalance := gns.BalanceOf(tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}
