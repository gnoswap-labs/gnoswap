package launchpad

import (
	avl "gno.land/p/nt/avl/v0"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
	"testing"
)

func newLaunchpadDeposit() *Deposit {
	deposit := NewDeposit("deposit-1", "project-1", 30, adminAddr, 1000, 10, 20, 30)
	deposit.SetWithdrawnHeight(40)
	deposit.SetWithdrawnTime(50)
	return deposit
}

func newLaunchpadRewardManager() *RewardManager {
	manager := NewRewardManager(1000, 10, 20, 30, 40, 50)
	manager.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("100"))
	manager.SetAccumulatedRewardPerDepositX128(u256.MustFromDecimal("200"))
	manager.SetTotalClaimedAmount(300)
	manager.SetAccumulatedDistributeAmount(400)
	manager.SetAccumulatedHeight(500)
	manager.SetAccumulatedTime(600)
	rewards := avl.NewTree()
	rewards.Set("deposit-1", NewRewardState(u256.MustFromDecimal("700"), 800, 900, 1000, 1100))
	manager.SetRewards(rewards)
	return manager
}

func newLaunchpadProject() *Project {
	project := NewProject("project-name", "token-path", 1000, adminAddr, 10, 20)
	project.SetConditions(map[string]*ProjectCondition{
		"token-path": NewProjectCondition("token-path", 500),
	})
	tier := NewProjectTier(project.ID(), 30, 1000, 30, 60)
	tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("111"))
	project.SetTiers(map[int64]*ProjectTier{30: tier})
	project.SetTiersRatios(map[int64]int64{30: 25, 90: 75})
	return project
}

func firstRewardState(t *testing.T, rewards *avl.Tree) *RewardState {
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

func TestMutableLaunchpadGetterIsolation(t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockLaunchpad)
		getter    func(t *testing.T) any
		mutate    func(result any)
		assertRaw func(t *testing.T, m *MockLaunchpad)
	}{
		{
			name: "GetProjectIDs",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectIDs", []string{"project-1", "project-2"}) },
			getter: func(t *testing.T) any { return GetProjectIDs(0, 10) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "project-3")
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				values := m.Response.data["GetProjectIDs"][0].([]string)
				uassert.Equal(t, "project-1", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetProject",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProject", newLaunchpadProject(), nil) },
			getter: func(t *testing.T) any {
				value, err := GetProject("project-1")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				project := result.(*Project)
				project.SetID("mutated-project")
				project.SetName("mutated-name")
				project.SetTokenPath("mutated-token")
				project.SetDepositAmount(2000)
				project.SetCreatedHeight(99)
				project.SetCreatedAt(88)
				project.SetTiersRatios(map[int64]int64{30: 100})
				project.Conditions()["token-path"].minimumAmount = 999
				project.Tiers()[30].SetTotalDepositAmount(777)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				project := m.Response.data["GetProject"][0].(*Project)
				uassert.Equal(t, "project-name", project.Name())
				uassert.Equal(t, "token-path", project.TokenPath())
				uassert.Equal(t, int64(1000), project.DepositAmount())
				uassert.Equal(t, int64(10), project.CreatedHeight())
				uassert.Equal(t, int64(20), project.CreatedAt())
				uassert.Equal(t, int64(500), project.conditions["token-path"].MinimumAmount())
				uassert.Equal(t, int64(0), project.tiers[30].TotalDepositAmount())
				uassert.Equal(t, int64(25), project.tiersRatios[30])
			},
		},
		{
			name: "GetProjectCondition",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectCondition", NewProjectCondition("token-path", 500), nil) },
			getter: func(t *testing.T) any {
				value, err := GetProjectCondition("project-1", "token-path")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				condition := result.(*ProjectCondition)
				condition.tokenPath = "mutated-token"
				condition.minimumAmount = 999
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				condition := m.Response.data["GetProjectCondition"][0].(*ProjectCondition)
				uassert.Equal(t, "token-path", condition.TokenPath())
				uassert.Equal(t, int64(500), condition.MinimumAmount())
			},
		},
		{
			name: "GetProjectTier",
			setup: func(m *MockLaunchpad) {
				tier := NewProjectTier("project-1", 30, 1000, 10, 20)
				tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("100"))
				m.Response.Set("GetProjectTier", tier, nil)
			},
			getter: func(t *testing.T) any {
				value, err := GetProjectTier("project-1", 30)
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				tier := result.(*ProjectTier)
				tier.SetDistributeAmountPerSecondX128(u256.MustFromDecimal("200"))
				tier.SetTotalDepositAmount(300)
				tier.SetTotalWithdrawAmount(400)
				tier.SetTotalDepositCount(500)
				tier.SetTotalWithdrawCount(600)
				tier.SetTotalCollectedAmount(700)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				tier := m.Response.data["GetProjectTier"][0].(*ProjectTier)
				uassert.Equal(t, "100", tier.DistributeAmountPerSecondX128().ToString())
				uassert.Equal(t, int64(0), tier.TotalDepositAmount())
				uassert.Equal(t, int64(0), tier.TotalWithdrawAmount())
				uassert.Equal(t, int64(0), tier.TotalDepositCount())
				uassert.Equal(t, int64(0), tier.TotalWithdrawCount())
				uassert.Equal(t, int64(0), tier.TotalCollectedAmount())
			},
		},
		{
			name: "GetProjectTiersRatios",
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
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTierDistributeAmountPerSecondX128", u256.MustFromDecimal("100"), nil) },
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
			name: "GetProjectTierDepositIDs",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTierDepositIDs", []string{"deposit-1", "deposit-2"}) },
			getter: func(t *testing.T) any { return GetProjectTierDepositIDs("project-1", 30, 0, 10) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "deposit-3")
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				values := m.Response.data["GetProjectTierDepositIDs"][0].([]string)
				uassert.Equal(t, "deposit-1", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetDeposit",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetDeposit", newLaunchpadDeposit(), nil) },
			getter: func(t *testing.T) any {
				value, err := GetDeposit("deposit-1")
				uassert.NoError(t, err)
				return value
			},
			mutate: func(result any) {
				deposit := result.(*Deposit)
				deposit.SetID("mutated-deposit")
				deposit.SetProjectID("mutated-project")
				deposit.SetTier(90)
				deposit.SetDepositAmount(2000)
				deposit.SetCreatedHeight(99)
				deposit.SetCreatedAt(88)
				deposit.SetWithdrawnHeight(77)
				deposit.SetWithdrawnTime(66)
				deposit.SetEndTime(55)
			},
			assertRaw: func(t *testing.T, m *MockLaunchpad) {
				deposit := m.Response.data["GetDeposit"][0].(*Deposit)
				uassert.Equal(t, "deposit-1", deposit.ID())
				uassert.Equal(t, "project-1", deposit.ProjectID())
				uassert.Equal(t, int64(30), deposit.Tier())
				uassert.Equal(t, int64(1000), deposit.DepositAmount())
				uassert.Equal(t, int64(10), deposit.CreatedHeight())
				uassert.Equal(t, int64(20), deposit.CreatedAt())
				uassert.Equal(t, int64(40), deposit.WithdrawnHeight())
				uassert.Equal(t, int64(50), deposit.WithdrawnTime())
				uassert.Equal(t, int64(30), deposit.EndTime())
			},
		},
		{
			name: "GetRewardState",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetRewardState", NewRewardState(u256.MustFromDecimal("700"), 800, 900, 1000, 1100), nil) },
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
				rewardState.SetAccumulatedHeight(1014)
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
				uassert.Equal(t, int64(0), rewardState.AccumulatedHeight())
				uassert.Equal(t, int64(0), rewardState.AccumulatedTime())
				uassert.Equal(t, int64(0), rewardState.ClaimedAmount())
			},
		},
		{
			name: "GetProjectTierRewardManager",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTierRewardManager", newLaunchpadRewardManager(), nil) },
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
				manager.SetAccumulatedHeight(1006)
				manager.SetAccumulatedTime(1007)
				manager.SetRewardClaimableDuration(1008)
				rewardState := firstRewardState(t, manager.Rewards())
				rewardState.SetPriceDebtX128(u256.MustFromDecimal("303"))
				rewardState.SetClaimableTime(1009)
				rewardState.SetDepositAmount(1010)
				rewardState.SetDistributeStartTime(1011)
				rewardState.SetDistributeEndTime(1012)
				rewardState.SetAccumulatedRewardAmount(1013)
				rewardState.SetAccumulatedHeight(1014)
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
				uassert.Equal(t, int64(500), manager.AccumulatedHeight())
				uassert.Equal(t, int64(600), manager.AccumulatedTime())
				uassert.Equal(t, int64(30), manager.RewardClaimableDuration())
				rewardState := firstRewardState(t, manager.Rewards())
				uassert.Equal(t, "700", rewardState.PriceDebtX128().ToString())
				uassert.Equal(t, int64(1100), rewardState.ClaimableTime())
				uassert.Equal(t, int64(800), rewardState.DepositAmount())
				uassert.Equal(t, int64(900), rewardState.DistributeStartTime())
				uassert.Equal(t, int64(1000), rewardState.DistributeEndTime())
				uassert.Equal(t, int64(0), rewardState.AccumulatedRewardAmount())
				uassert.Equal(t, int64(0), rewardState.AccumulatedHeight())
				uassert.Equal(t, int64(0), rewardState.AccumulatedTime())
				uassert.Equal(t, int64(0), rewardState.ClaimedAmount())
			},
		},
		{
			name: "GetProjectTierRewardDistributeAmountPerSecondX128",
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTierRewardDistributeAmountPerSecondX128", u256.MustFromDecimal("300"), nil) },
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
			setup: func(m *MockLaunchpad) { m.Response.Set("GetProjectTierRewardAccumulatedRewardPerDepositX128", u256.MustFromDecimal("500"), nil) },
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
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			mockLaunchpad := newMockLaunchpad("v1")
			implementation = mockLaunchpad
			tt.setup(mockLaunchpad)
			result := tt.getter(t)
			tt.mutate(result)
			tt.assertRaw(t, mockLaunchpad)
		})
	}
}
