package launchpad

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func newLaunchpadDeposit() *Deposit {
	depositValue := MakeDeposit("deposit-1", "project-1", 30, adminAddr, 1000, 10, 20, 30)
	deposit := &depositValue
	deposit.SetWithdrawnHeight(40)
	deposit.SetWithdrawnTime(50)
	return deposit
}

func TestMakeDepositReturnsValue(cur realm, t *testing.T) {
	deposit := MakeDeposit("deposit-1", "project-1", 30, adminAddr, 1000, 10, 20, 30)

	uassert.Equal(t, "deposit-1", deposit.ID())
	uassert.Equal(t, "project-1", deposit.ProjectID())
	uassert.Equal(t, int64(30), deposit.Tier())
	uassert.Equal(t, adminAddr, deposit.Depositor())
	uassert.Equal(t, int64(1000), deposit.DepositAmount())
	uassert.Equal(t, int64(10), deposit.CreatedHeight())
	uassert.Equal(t, int64(20), deposit.CreatedAt())
	uassert.Equal(t, int64(30), deposit.EndTime())
	uassert.Equal(t, int64(0), deposit.WithdrawnHeight())
}

func TestDefaultDepositReturnsZeroValue(cur realm, t *testing.T) {
	deposit := DefaultDeposit()

	uassert.Equal(t, "", deposit.ID())
	uassert.Equal(t, "", deposit.ProjectID())
	uassert.Equal(t, int64(0), deposit.DepositAmount())
	uassert.Equal(t, int64(0), deposit.WithdrawnHeight())
}

func newLaunchpadRewardManager() *RewardManager {
	manager := NewRewardManager(1000, 10, 20, 30)
	manager.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("100"))
	manager.SetAccumulatedRewardPerDepositX128(u256.MustFromDecimal("200"))
	manager.SetTotalClaimedAmount(300)
	manager.SetAccumulatedDistributeAmount(400)
	manager.SetAccumulatedTime(600)
	rewards := bptree.NewBPTreeN(16)
	rewards.Set("deposit-1", NewRewardState(u256.MustFromDecimal("700"), 800, 900, 1000, 1100))
	manager.SetRewards(rewards)
	return manager
}

func newLaunchpadProject() *Project {
	project := MakeProject("project-name", "token-path", 1000, adminAddr, 10, 20)
	project.SetConditions(map[string]ProjectCondition{
		"token-path": MakeProjectCondition("token-path", 500),
	})
	tier := MakeProjectTier(project.ID(), 30, 1000, 30, 60)
	tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("111"))
	project.SetTiers(map[int64]ProjectTier{30: tier})
	project.SetTiersRatios(map[int64]int64{30: 25, 90: 75})
	return &project
}

func firstRewardState(t *testing.T, rewards *bptree.BPTree) *RewardState {
	t.Helper()

	var rewardState *RewardState
	rewards.Iterate("", "", func(_ string, value any) bool {
		rewardState = value.(*RewardState)
		return true
	})

	if rewardState == nil {
		t.Fatal("expected reward state in rewards tree")
	}

	return rewardState
}

func TestMutableLaunchpadGetterIsolation(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockLaunchpad)
		getter    func(t *testing.T) any
		mutate    func(result any)
		assertRaw func(t *testing.T, m *MockLaunchpad)
	}{
		{
			name: "GetProjectCondition",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetProjectCondition", MakeProjectCondition("token-path", 500), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectCondition("project-1", "token-path")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				condition := result.(ProjectCondition)
				condition.tokenPath = "mutated-token"
				condition.minimumAmount = 999
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				condition := m.Response.data["GetProjectCondition"][0].(ProjectCondition)
				uassert.Equal(t, "token-path", condition.TokenPath())
				uassert.Equal(t, int64(500), condition.MinimumAmount())
			},
		},
		{
			name: "GetProjectTier",
			setup: func(m *MockLaunchpad) {
				tier := MakeProjectTier("project-1", 30, 1000, 10, 20)
				tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("100"))
				m.Response.Set("GetProjectTier", tier, nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTier("project-1", 30)
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				tier := result.(ProjectTier)
				tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("200"))
				tier.SetTotalDepositAmount(300)
				tier.SetTotalWithdrawAmount(400)
				tier.SetTotalDepositCount(500)
				tier.SetTotalWithdrawCount(600)
				tier.SetTotalCollectedAmount(700)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				tier := m.Response.data["GetProjectTier"][0].(ProjectTier)
				uassert.Equal(t, "100", tier.DistributeAmountPerSecondX128().ToString())
				uassert.Equal(t, int64(0), tier.TotalDepositAmount())
				uassert.Equal(t, int64(0), tier.TotalWithdrawAmount())
				uassert.Equal(t, int64(0), tier.TotalDepositCount())
				uassert.Equal(t, int64(0), tier.TotalWithdrawCount())
				uassert.Equal(t, int64(0), tier.TotalCollectedAmount())
			},
		},
		{
			name:  "GetProjectTiersRatios",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTiersRatios", map[int64]int64{30: 25, 90: 75}, nil) },
			getter: func(t *testing.T) any {
				values, err := GetProjectTiersRatios("project-1")
				uassert.NoError(t, err)
				return values
			},
			mutate: func(result any) {
				values := result.(map[int64]int64)
				values[30] = 100
				values[180] = 50
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				values := m.Response.data["GetProjectTiersRatios"][0].(map[int64]int64)
				uassert.Equal(t, int64(25), values[30])
				_, ok := values[180]
				uassert.Equal(t, false, ok)
			},
		},
		{
			name: "GetProjectTierDistributeAmountPerSecondX128",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetProjectTierDistributeAmountPerSecondX128", u256.MustFromDecimal("100"), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTierDistributeAmountPerSecondX128("project-1", 30)
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("200")) },
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				value := m.Response.data["GetProjectTierDistributeAmountPerSecondX128"][0].(*u256.Uint)
				uassert.Equal(t, "100", value.ToString())
			},
		},
		{
			name: "GetRewardState",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetRewardState", NewRewardState(u256.MustFromDecimal("700"), 800, 900, 1000, 1100), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetRewardState("project-1:30", "deposit-1")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				rewardState := result.(*RewardState)
				rewardState.SetPriceDebtX128(u256.MustFromDecimal("303"))
				rewardState.SetClaimableTime(1009)
				rewardState.SetDepositAmount(1010)
				rewardState.SetDistributeStartTime(1011)
				rewardState.SetDistributeEndTime(1012)
				rewardState.SetAccumulatedRewardAmount(1013)
				rewardState.SetAccumulatedTime(1015)
				rewardState.SetClaimedAmount(1016)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				rewardState := m.Response.data["GetRewardState"][0].(*RewardState)
				uassert.Equal(t, "700", rewardState.PriceDebtX128().ToString())
				uassert.Equal(t, int64(1100), rewardState.ClaimableTime())
				uassert.Equal(t, int64(800), rewardState.DepositAmount())
				uassert.Equal(t, int64(900), rewardState.DistributeStartTime())
				uassert.Equal(t, int64(1000), rewardState.DistributeEndTime())
				uassert.Equal(t, int64(0), rewardState.AccumulatedRewardAmount())
				uassert.Equal(t, int64(0), rewardState.AccumulatedTime())
				uassert.Equal(t, int64(0), rewardState.ClaimedAmount())
			},
		},
		{
			name: "GetProjectTierRewardManager",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetProjectTierRewardManager", newLaunchpadRewardManager(), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTierRewardManager("project-1:30")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				manager := result.(*RewardManager)
				manager.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("101"))
				manager.SetAccumulatedRewardPerDepositX128(u256.MustFromDecimal("202"))
				manager.SetTotalDistributeAmount(1001)
				manager.SetTotalClaimedAmount(1002)
				manager.SetDistributeStartTime(1003)
				manager.SetDistributeEndTime(1004)
				manager.SetAccumulatedDistributeAmount(1005)
				manager.SetAccumulatedTime(1007)
				manager.SetRewardClaimableDuration(1008)
				rewardState := firstRewardState(t, manager.Rewards())
				rewardState.SetPriceDebtX128(u256.MustFromDecimal("303"))
				rewardState.SetClaimableTime(1009)
				rewardState.SetDepositAmount(1010)
				rewardState.SetDistributeStartTime(1011)
				rewardState.SetDistributeEndTime(1012)
				rewardState.SetAccumulatedRewardAmount(1013)
				rewardState.SetAccumulatedTime(1015)
				rewardState.SetClaimedAmount(1016)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				manager := m.Response.data["GetProjectTierRewardManager"][0].(*RewardManager)
				uassert.Equal(t, "100", manager.DistributeAmountPerSecondX128().ToString())
				uassert.Equal(t, "200", manager.AccumulatedRewardPerDepositX128().ToString())
				uassert.Equal(t, int64(1000), manager.TotalDistributeAmount())
				uassert.Equal(t, int64(300), manager.TotalClaimedAmount())
				uassert.Equal(t, int64(10), manager.DistributeStartTime())
				uassert.Equal(t, int64(20), manager.DistributeEndTime())
				uassert.Equal(t, int64(400), manager.AccumulatedDistributeAmount())
				uassert.Equal(t, int64(600), manager.AccumulatedTime())
				uassert.Equal(t, int64(30), manager.RewardClaimableDuration())
				rewardState := firstRewardState(t, manager.Rewards())
				uassert.Equal(t, "700", rewardState.PriceDebtX128().ToString())
				uassert.Equal(t, int64(1100), rewardState.ClaimableTime())
				uassert.Equal(t, int64(800), rewardState.DepositAmount())
				uassert.Equal(t, int64(900), rewardState.DistributeStartTime())
				uassert.Equal(t, int64(1000), rewardState.DistributeEndTime())
				uassert.Equal(t, int64(0), rewardState.AccumulatedRewardAmount())
				uassert.Equal(t, int64(0), rewardState.AccumulatedTime())
				uassert.Equal(t, int64(0), rewardState.ClaimedAmount())
			},
		},
		{
			name: "GetProjectTierRewardDistributeAmountPerSecondX128",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetProjectTierRewardDistributeAmountPerSecondX128", u256.MustFromDecimal("300"), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTierRewardDistributeAmountPerSecondX128("project-1:30")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("400")) },
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				value := m.Response.data["GetProjectTierRewardDistributeAmountPerSecondX128"][0].(*u256.Uint)
				uassert.Equal(t, "300", value.ToString())
			},
		},
		{
			name: "GetProjectTierRewardAccumulatedRewardPerDepositX128",
			setup: func(m *MockLaunchpad) {
				m.Response.Set("GetProjectTierRewardAccumulatedRewardPerDepositX128", u256.MustFromDecimal("500"), nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTierRewardAccumulatedRewardPerDepositX128("project-1:30")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("600")) },
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				value := m.Response.data["GetProjectTierRewardAccumulatedRewardPerDepositX128"][0].(*u256.Uint)
				uassert.Equal(t, "500", value.ToString())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			mockLaunchpad := newMockLaunchpad("v1")
			implementation = mockLaunchpad
			tt.setup(mockLaunchpad)
			result := tt.getter(t)
			tt.mutate(result)
			tt.assertRaw(t, mockLaunchpad)
		})
	}
}

func TestGetDepositReturnsValue(cur realm, t *testing.T) {
	resetTestState(cur, t)
	mockLaunchpad := newMockLaunchpad("v1")
	implementation = mockLaunchpad

	expected := newLaunchpadDeposit()
	mockLaunchpad.Response.Set("GetDeposit", *expected, nil)

	deposit, err := GetDeposit("deposit-1")

	uassert.NoError(t, err)
	uassert.Equal(t, expected.ID(), deposit.ID())
	uassert.Equal(t, expected.ProjectID(), deposit.ProjectID())
	uassert.Equal(t, expected.Tier(), deposit.Tier())
	uassert.Equal(t, expected.DepositAmount(), deposit.DepositAmount())
	uassert.Equal(t, expected.CreatedHeight(), deposit.CreatedHeight())
	uassert.Equal(t, expected.CreatedAt(), deposit.CreatedAt())
	uassert.Equal(t, expected.WithdrawnHeight(), deposit.WithdrawnHeight())
	uassert.Equal(t, expected.WithdrawnTime(), deposit.WithdrawnTime())
	uassert.Equal(t, expected.EndTime(), deposit.EndTime())
}

func TestReadOnlyTreeGetters(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		method   string
		getter   func() *rotree.ReadOnlyTree
		wantKeys []string
	}{
		{
			name:     "GetProjects",
			method:   "GetProjects",
			getter:   func() *rotree.ReadOnlyTree { return GetProjects() },
			wantKeys: []string{"project-1", "project-2"},
		},
		{
			name:     "GetProjectTierRewards",
			method:   "GetProjectTierRewards",
			getter:   func() *rotree.ReadOnlyTree { return GetProjectTierRewards("project-1", 30) },
			wantKeys: []string{"deposit-1", "deposit-2"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)
			mockLaunchpad := newMockLaunchpad("v1")
			implementation = mockLaunchpad

			stored := bptree.NewBPTree32()
			for i, key := range tt.wantKeys {
				stored.Set(key, i)
			}
			mockLaunchpad.Response.Set(tt.method, rotree.Wrap(stored, nil))

			got := tt.getter()
			uassert.Equal(t, len(tt.wantKeys), got.Size())

			keys := make([]string, 0, got.Size())
			got.IterateByOffset(0, got.Size(), func(key string, _ any) bool {
				keys = append(keys, key)
				return false
			})
			for i, want := range tt.wantKeys {
				uassert.Equal(t, want, keys[i])
			}

			// The view refuses writes, so the stored tree stays untouched.
			uassert.PanicsWithMessage(t, cur, "Set operation not supported on ReadOnlyTree", func() {
				got.Set("mutated", 0)
			})
			uassert.PanicsWithMessage(t, cur, "Remove operation not supported on ReadOnlyTree", func() {
				got.Remove(tt.wantKeys[0])
			})
			uassert.Equal(t, len(tt.wantKeys), stored.Size())
		})
	}
}

func TestReadOnlyTreeGetters_NoImplementationResponse(cur realm, t *testing.T) {
	resetTestState(cur, t)
	mockLaunchpad := newMockLaunchpad("v1")
	implementation = mockLaunchpad

	uassert.True(t, GetProjects() == nil)
	uassert.True(t, GetProjectTierRewards("project-1", 30) == nil)
}

func TestProjectValuePayloadIsolation(t *testing.T) {
	project := MakeProject("project", "token-path", 1_000, adminAddr, 10, 20)

	inputCondition := MakeProjectCondition("token-path", 500)
	inputTier := MakeProjectTier(project.ID(), 30, 1_000, 30, 60)
	inputRate := u256.MustFromDecimal("100")
	inputTier.SetDistributeAmountPerSecondX128(inputRate)

	conditions := map[string]ProjectCondition{"token-path": inputCondition}
	tiers := map[int64]ProjectTier{30: inputTier}
	project.SetConditions(conditions)
	project.SetTiers(tiers)

	// Mutating the caller's maps and numeric payload after a setter call must
	// not mutate the project's owned state.
	conditions["other-token"] = MakeProjectCondition("other-token", 1)
	tiers[90] = MakeProjectTier(project.ID(), 90, 2_000, 30, 90)
	inputRate.Set(u256.MustFromDecimal("999"))

	storedCondition, err := project.GetCondition("token-path")
	uassert.NoError(t, err)
	uassert.Equal(t, "token-path", storedCondition.TokenPath())
	uassert.Equal(t, int64(500), storedCondition.MinimumAmount())

	storedTier, err := project.GetTier(30)
	uassert.NoError(t, err)
	uassert.Equal(t, "100", storedTier.DistributeAmountPerSecondX128().ToString())

	missingCondition, err := project.GetCondition("other-token")
	uassert.ErrorContains(t, err, "condition(other-token) not found")
	uassert.Equal(t, "", missingCondition.TokenPath())
	missingTier, err := project.GetTier(90)
	uassert.ErrorContains(t, err, "tier(90) not found")
	uassert.Equal(t, int64(0), missingTier.TotalDistributeAmount())

	// Returned maps and entries are copies. Mutating either copy must leave the
	// source project unchanged.
	returnedConditions := project.Conditions()
	returnedCondition := returnedConditions["token-path"]
	returnedCondition.tokenPath = "mutated-token"
	returnedConditions["token-path"] = returnedCondition

	returnedTiers := project.Tiers()
	returnedTier := returnedTiers[30]
	returnedTier.SetTotalDepositAmount(123)
	returnedRate := returnedTier.DistributeAmountPerSecondX128()
	returnedRate.Set(u256.MustFromDecimal("888"))
	returnedTiers[30] = returnedTier

	storedCondition, err = project.GetCondition("token-path")
	uassert.NoError(t, err)
	uassert.Equal(t, "token-path", storedCondition.TokenPath())
	storedTier, err = project.GetTier(30)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), storedTier.TotalDepositAmount())
	uassert.Equal(t, "100", storedTier.DistributeAmountPerSecondX128().ToString())

	// A direct Project value copy must use COW map updates.
	copyProject := project
	copyProject.SetName("mutated-project")
	copyProject.SetCondition("new-token", MakeProjectCondition("new-token", 2))
	copyProject.SetTier(30, MakeProjectTier(project.ID(), 30, 2_000, 30, 60))

	uassert.Equal(t, "project", project.Name())
	_, err = project.GetCondition("new-token")
	uassert.ErrorContains(t, err, "condition(new-token) not found")
	storedTier, err = project.GetTier(30)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(1_000), storedTier.TotalDistributeAmount())
}

func TestProjectTierNumericPayloadIsolation(t *testing.T) {
	inputRate := u256.MustFromDecimal("100")
	tier := MakeProjectTier("project", 30, 1_000, 10, 20)
	tier.SetDistributeAmountPerSecondX128(inputRate)

	// Setter copies its input and getter returns a fresh mutable number.
	inputRate.Set(u256.MustFromDecimal("200"))
	returnedRate := tier.DistributeAmountPerSecondX128()
	returnedRate.Set(u256.MustFromDecimal("300"))
	uassert.Equal(t, "100", tier.DistributeAmountPerSecondX128().ToString())

	// Clone must also sever the internal numeric pointer.
	clone := tier.Clone()
	clone.distributeAmountPerSecondX128.Set(u256.MustFromDecimal("400"))
	uassert.Equal(t, "100", tier.DistributeAmountPerSecondX128().ToString())
}
