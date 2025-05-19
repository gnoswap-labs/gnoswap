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
			name: "panic if not admin",
			setup: func() {
				testing.SetRealm(dummyCaller)
				func() {
					testing.SetRealm(dummyCaller)
					cross(halt.SetHaltByAdmin)(false)
				}()
			},
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "caller(g1v36k6mtegdskcmr9wf047h6lta047h6ljmnks7) has no permission",
		},
		{
			name: "panic if halted",
			setup: func() {
				testing.SetRealm(adminRealm)
				func() {
					testing.SetRealm(adminRealm)
					cross(halt.SetHaltByAdmin)(true)
				}()
			},
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-COMMUNITY_POOL-005] halted || community pool is currently halted",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.caller != (std.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					TransferTokenByAdmin(tt.tokenPath, tt.to, tt.amount)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(tt.to)
				TransferTokenByAdmin(tt.tokenPath, tt.to, tt.amount)
				receiverNewBalance := gns.BalanceOf(tt.to)
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
				func() {
					testing.SetRealm(adminRealm)
					cross(halt.SetHaltByAdmin)(true)
				}()
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
				func() {
					testing.SetRealm(adminRealm)
					cross(halt.SetHaltByAdmin)(false)
				}()
			},
			tokenPath:   consts.GNS_PATH,
			to:          dummyReceiver,
			amount:      1000,
			shouldPanic: true,
			panicMsg:    "caller(g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d) has no permission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.caller != (std.Realm{}) {
				testing.SetRealm(tt.caller)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					TransferToken(tt.tokenPath, tt.to, tt.amount)
				})
			} else {
				receiverOldBalance := gns.BalanceOf(tt.to)
				TransferToken(tt.tokenPath, tt.to, tt.amount)
				receiverNewBalance := gns.BalanceOf(tt.to)
				uassert.Equal(t, receiverNewBalance-receiverOldBalance, tt.amount)
			}
		})
	}
}

func TestTransferTokenByGovernance(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		caller      std.Realm
		tokenPath   string
		to          std.Address
		amount      int64
		panicMsg    string
	}{
		{
			name: "panic if not admin",
			setup: func() {
				testing.SetRealm(dummyCaller)
			},
			panicMsg: "caller(g1v36k6mtegdskcmr9wf047h6lta047h6ljmnks7) has no permission",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			uassert.PanicsWithMessage(t, tt.panicMsg, func() {
				TransferToken(tt.tokenPath, tt.to, tt.amount)
			})
		})
	}
}
