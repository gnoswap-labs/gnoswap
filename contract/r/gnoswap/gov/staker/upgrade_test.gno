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
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
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

				impl := implementation.(*MockGovStaker)
				uassert.Equal(t, impl.Version, tt.expectedVersion)
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

			// Action
			Delegate(cross, tt.to, tt.amount, tt.referrer)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("Delegate") != 1 {
				t.Error("Delegate was not called on the implementation")
			}
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

			// Action
			Undelegate(cross, tt.from, tt.amount)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("Undelegate") != 1 {
				t.Error("Undelegate was not called on the implementation")
			}
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

			// Action
			Redelegate(cross, tt.delegatee, tt.newDelegatee, tt.amount)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("Redelegate") != 1 {
				t.Error("Redelegate was not called on the implementation")
			}
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

			// Action
			CollectUndelegatedGns(cross)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("CollectUndelegatedGns") != 1 {
				t.Error("CollectUndelegatedGns was not called on the implementation")
			}
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

			// Action
			CollectReward(cross)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("CollectReward") != 1 {
				t.Error("CollectReward was not called on the implementation")
			}
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

			// Action
			CollectRewardFromLaunchPad(cross, tt.to)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("CollectRewardFromLaunchPad") != 1 {
				t.Error("CollectRewardFromLaunchPad was not called on the implementation")
			}
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

			// Action
			SetAmountByProjectWallet(cross, tt.addr, tt.amount, tt.add)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("SetAmountByProjectWallet") != 1 {
				t.Error("SetAmountByProjectWallet was not called on the implementation")
			}
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

			// Action
			CleanStakerDelegationSnapshotByAdmin(cross, tt.threshold)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("CleanStakerDelegationSnapshotByAdmin") != 1 {
				t.Error("CleanStakerDelegationSnapshotByAdmin was not called on the implementation")
			}
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

			// Action
			SetUnDelegationLockupPeriodByAdmin(cross, tt.period)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("SetUnDelegationLockupPeriodByAdmin") != 1 {
				t.Error("SetUnDelegationLockupPeriodByAdmin was not called on the implementation")
			}
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

			// Action
			GetTotalxGnsSupply()

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetTotalxGnsSupply") != 1 {
				t.Error("GetTotalxGnsSupply was not called on the implementation")
			}
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

			// Action
			GetTotalVoteWeight()

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetTotalVoteWeight") != 1 {
				t.Error("GetTotalVoteWeight was not called on the implementation")
			}
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

			// Action
			GetTotalDelegated()

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetTotalDelegated") != 1 {
				t.Error("GetTotalDelegated was not called on the implementation")
			}
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

			// Action
			GetTotalLockedAmount()

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetTotalLockedAmount") != 1 {
				t.Error("GetTotalLockedAmount was not called on the implementation")
			}
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

			// Action
			GetLockedAmount()

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetLockedAmount") != 1 {
				t.Error("GetLockedAmount was not called on the implementation")
			}
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

			// Action
			GetDelegationSnapshots(tt.snapshotTime)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetDelegationSnapshots") != 1 {
				t.Error("GetDelegationSnapshots was not called on the implementation")
			}
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

			// Action
			GetClaimableRewardByAddress(tt.addr)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetClaimableRewardByAddress") != 1 {
				t.Error("GetClaimableRewardByAddress was not called on the implementation")
			}
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

			// Action
			GetClaimableRewardByLaunchpad(tt.addr)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetClaimableRewardByLaunchpad") != 1 {
				t.Error("GetClaimableRewardByLaunchpad was not called on the implementation")
			}
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

			// Action
			GetClaimableRewardByRewardID(tt.rewardID)

			// Assert
			mockGovStaker := implementation.(*MockGovStaker)
			if mockGovStaker.Response.CallCount("GetClaimableRewardByRewardID") != 1 {
				t.Error("GetClaimableRewardByRewardID was not called on the implementation")
			}
		})
	}
}
