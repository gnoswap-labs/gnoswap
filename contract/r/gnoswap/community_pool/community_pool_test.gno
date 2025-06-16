package community_pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/halt"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	communityPoolAddr, _ = access.GetAddress(access.ROLE_COMMUNITY_POOL)

	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)

	dummyCaller   = std.NewUserRealm(testutils.TestAddress("dummyCaller"))
	dummyReceiver = testutils.TestAddress("dummyReceiver")
)

func resetCommunityPoolState(t *testing.T) {
	testing.SetRealm(adminRealm)
	halt.SetHaltByAdmin(cross, false)
	gns.Transfer(cross, communityPoolAddr, 10_000)
}

func TestTransferTokenByAdmin(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		caller      std.Realm
		tokenPath   string
		to          std.Address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic if halted",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltByAdmin(cross, true)
			},
			caller:      adminRealm,
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-COMMUNITY_POOL-005] halted || community pool is currently halted",
		},
		{
			name: "panic if not admin",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltByAdmin(cross, false)
			},
			caller:      dummyCaller,
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "caller(g1v36k6mtegdskcmr9wf047h6lta047h6ljmnks7) has no permission",
		},
		// {
		// 	name: "panic if not enough balance",
		// 	setup: func() {
		// 		testing.SetRealm(adminRealm)
		// 		gns.Transfer(cross, communityPoolAddr, 1)
		// 	},
		// 	caller:      adminRealm,
		// 	tokenPath:   consts.GNS_PATH,
		// 	to:          dummyReceiver,
		// 	amount:      20_000,
		// 	shouldPanic: true,
		// 	panicMsg:    "insufficient balance",
		// },
		{
			name: "success if enough balance",
			setup: func() {
				testing.SetRealm(adminRealm)
				gns.Transfer(cross, communityPoolAddr, 10_000)
			},
			caller:    adminRealm,
			tokenPath: consts.GNS_PATH,
			to:        dummyReceiver,
			amount:    10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetCommunityPoolState(t)

			if tt.setup != nil {
				tt.setup()
			}

			if tt.caller != (std.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						TransferTokenByAdmin(cur, tt.tokenPath, tt.to, tt.amount)
					}(cross)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(cross, tt.to)
				func(cur realm) {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
					TransferTokenByAdmin(cross, tt.tokenPath, tt.to, tt.amount)
				}(cross)
				receiverNewBalance := gns.BalanceOf(cross, tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}

func TestTransferToken(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		caller      std.Realm
		tokenPath   string
		to          std.Address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "panic if halted",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltByAdmin(cross, true)
			},
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-COMMUNITY_POOL-005] halted || community pool is currently halted",
		},
		{
			name: "panic if not governance",
			setup: func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltByAdmin(cross, false)
			},
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "caller(g100fnnlz5eh87p5hvwt8pf279lxaelm8k8md049) has no permission",
		},
		{
			name: "governance can't transfer community pool token",
			setup: func() {
				testing.SetRealm(adminRealm)
			},
			caller:      govRealm,
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      10_001,
			shouldPanic: true,
			panicMsg:    "insufficient balance",
		},
		// {
		// 	name:      "governance can transfer community pool token",
		// 	setup: func() {
		// 		testing.SetRealm(adminRealm)
		// 		gns.Transfer(cross, communityPoolAddr, 10_000)
		// 	},
		// 	caller:    govRealm,
		// 	tokenPath: consts.GNS_PATH,
		// 	to:        dummyReceiver,
		// 	amount:    1,
		// },
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetCommunityPoolState(t)

			if tt.setup != nil {
				tt.setup()
			}

			if tt.caller != (std.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						TransferToken(cur, tt.tokenPath, tt.to, tt.amount)
					}(cross)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(cross, tt.to)
				func(cur realm) {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
					TransferToken(cur, tt.tokenPath, tt.to, tt.amount)
				}(cross)
				receiverNewBalance := gns.BalanceOf(cross, tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}

func TestPrivateTransferToken(t *testing.T) {
	tests := []struct {
		tokenPath   string
		to          std.Address
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			tokenPath:   "not_registered_token",
			to:          dummyReceiver,
			amount:      1,
			shouldPanic: true,
			panicMsg:    "unknown token: not_registered_token",
		},
		{
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.tokenPath, func(t *testing.T) {
			resetCommunityPoolState(t)
			testing.SetRealm(adminRealm)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					func(cur realm) {
						testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
						transferToken(tt.tokenPath, tt.to, tt.amount)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
					transferToken(tt.tokenPath, tt.to, tt.amount)
				}(cross)
			}
		})
	}
}
