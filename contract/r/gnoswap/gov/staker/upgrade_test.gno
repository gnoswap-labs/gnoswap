package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IGovStakerStore) IGovStaker
		callerRealm          runtime.Realm
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:        "register initializer is success",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"),
			initializer: makeMockInitializer("v1"),
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer already registered",
		},
		{
			name:                 "register initializer is failed by invalid domain path",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: caller is not in the domain path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
					RegisterInitializer(cross, tt.initializer)
				})
			} else {
				RegisterInitializer(cross, tt.initializer)
			}
		})
	}
}

// TestDelegate tests the Delegate proxy function
func TestDelegate(t *testing.T) {
	tests := []struct {
		name     string
		to       address
		amount   int64
		referrer string
	}{
		{
			name:     "delegate is success",
			to:       adminAddr,
			amount:   1000,
			referrer: "test_referrer",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			result := Delegate(cross, tt.to, tt.amount, tt.referrer)
			_ = result
		})
	}
}

// TestUndelegate tests the Undelegate proxy function
func TestUndelegate(t *testing.T) {
	tests := []struct {
		name   string
		from   address
		amount int64
	}{
		{
			name:   "undelegate is success",
			from:   adminAddr,
			amount: 500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			result := Undelegate(cross, tt.from, tt.amount)
			_ = result
		})
	}
}

// TestRedelegate tests the Redelegate proxy function
func TestRedelegate(t *testing.T) {
	tests := []struct {
		name         string
		delegatee    address
		newDelegatee address
		amount       int64
	}{
		{
			name:         "redelegate is success",
			delegatee:    adminAddr,
			newDelegatee: adminAddr,
			amount:       300,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			result := Redelegate(cross, tt.delegatee, tt.newDelegatee, tt.amount)
			_ = result
		})
	}
}

// TestCollectUndelegatedGns tests the CollectUndelegatedGns proxy function
func TestCollectUndelegatedGns(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "collect undelegated gns is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			result := CollectUndelegatedGns(cross)
			_ = result
		})
	}
}

// TestCollectReward tests the CollectReward proxy function
func TestCollectReward(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "collect reward is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			CollectReward(cross)
		})
	}
}

// TestCollectRewardFromLaunchPad tests the CollectRewardFromLaunchPad proxy function
func TestCollectRewardFromLaunchPad(t *testing.T) {
	tests := []struct {
		name string
		to   address
	}{
		{
			name: "collect reward from launchpad is success",
			to:   adminAddr,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			CollectRewardFromLaunchPad(cross, tt.to)
		})
	}
}

// TestSetAmountByProjectWallet tests the SetAmountByProjectWallet proxy function
func TestSetAmountByProjectWallet(t *testing.T) {
	tests := []struct {
		name   string
		addr   address
		amount int64
		add    bool
	}{
		{
			name:   "set amount by project wallet is success",
			addr:   adminAddr,
			amount: 1000,
			add:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			SetAmountByProjectWallet(cross, tt.addr, tt.amount, tt.add)
		})
	}
}

// TestCleanStakerDelegationSnapshotByAdmin tests the CleanStakerDelegationSnapshotByAdmin proxy function
func TestCleanStakerDelegationSnapshotByAdmin(t *testing.T) {
	tests := []struct {
		name      string
		threshold int64
	}{
		{
			name:      "clean staker delegation snapshot by admin is success",
			threshold: 100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			CleanStakerDelegationSnapshotByAdmin(cross, tt.threshold)
		})
	}
}

// TestSetUnDelegationLockupPeriodByAdmin tests the SetUnDelegationLockupPeriodByAdmin proxy function
func TestSetUnDelegationLockupPeriodByAdmin(t *testing.T) {
	tests := []struct {
		name   string
		period int64
	}{
		{
			name:   "set undelegation lockup period by admin is success",
			period: 86400,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))
			SetUnDelegationLockupPeriodByAdmin(cross, tt.period)
		})
	}
}

// TestGetTotalxGnsSupply tests the GetTotalxGnsSupply getter function
func TestGetTotalxGnsSupply(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total xGns supply is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetTotalxGnsSupply()
			_ = result
		})
	}
}

// TestGetTotalVoteWeight tests the GetTotalVoteWeight getter function
func TestGetTotalVoteWeight(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total vote weight is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetTotalVoteWeight()
			_ = result
		})
	}
}

// TestGetTotalDelegated tests the GetTotalDelegated getter function
func TestGetTotalDelegated(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total delegated is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetTotalDelegated()
			_ = result
		})
	}
}

// TestGetTotalLockedAmount tests the GetTotalLockedAmount getter function
func TestGetTotalLockedAmount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total locked amount is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetTotalLockedAmount()
			_ = result
		})
	}
}

// TestGetLockedAmount tests the GetLockedAmount getter function
func TestGetLockedAmount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get locked amount is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetLockedAmount()
			_ = result
		})
	}
}

// TestGetDelegationSnapshots tests the GetDelegationSnapshots getter function
func TestGetDelegationSnapshots(t *testing.T) {
	tests := []struct {
		name         string
		snapshotTime int64
	}{
		{
			name:         "get delegation snapshots is success",
			snapshotTime: 1234567890,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result, ok := GetDelegationSnapshots(tt.snapshotTime)
			_, _ = result, ok
		})
	}
}

// TestGetClaimableRewardByAddress tests the GetClaimableRewardByAddress getter function
func TestGetClaimableRewardByAddress(t *testing.T) {
	tests := []struct {
		name string
		addr address
	}{
		{
			name: "get claimable reward by address is success",
			addr: adminAddr,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetClaimableRewardByAddress(tt.addr)
			_ = result
		})
	}
}

// TestGetClaimableRewardByLaunchpad tests the GetClaimableRewardByLaunchpad getter function
func TestGetClaimableRewardByLaunchpad(t *testing.T) {
	tests := []struct {
		name string
		addr address
	}{
		{
			name: "get claimable reward by launchpad is success",
			addr: adminAddr,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetClaimableRewardByLaunchpad(tt.addr)
			_ = result
		})
	}
}

// TestGetClaimableRewardByRewardID tests the GetClaimableRewardByRewardID getter function
func TestGetClaimableRewardByRewardID(t *testing.T) {
	tests := []struct {
		name     string
		rewardID string
	}{
		{
			name:     "get claimable reward by reward ID is success",
			rewardID: "test_reward_id",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			result := GetClaimableRewardByRewardID(tt.rewardID)
			_ = result
		})
	}
}
