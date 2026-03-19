package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func newExternalIncentive() ExternalIncentive {
	return *NewExternalIncentive("incentive-1", "foo:bar:500", "reward-token", 1000, 10, 20, adminAddr, 30, 40, 50)
}

func newStakerDeposit() *Deposit {
	deposit := NewDeposit(adminAddr, "foo:bar:500", u256.MustFromDecimal("1000"), 10, -100, 100, []Warmup{{Index: 0, TimeDuration: 10, NextWarmupTime: 20, WarmupRatio: 30}})
	deposit.SetCollectedInternalReward(40)
	deposit.SetLastExternalIncentiveUpdatedAt(50)
	return deposit
}

func newStakerPool() *Pool {
	pool := NewPool("foo:bar:500", 10)
	pool.SetLastUnclaimableTime(20)
	pool.SetUnclaimableAcc(30)
	return pool
}

func TestMutableStakerGetterIsolation(t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockStaker)
		getter    func() any
		mutate    func(result any)
		assertRaw func(t *testing.T, m *MockStaker)
	}{
		{
			name: "GetPool",
			setup: func(m *MockStaker) { m.Response.Set("GetPool", newStakerPool()) },
			getter: func() any { return GetPool("foo:bar:500") },
			mutate: func(result any) {
				pool := result.(*Pool)
				pool.SetPoolPath("mutated:pool")
				pool.SetLastUnclaimableTime(99)
				pool.SetUnclaimableAcc(88)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				pool := m.Response.data["GetPool"][0].(*Pool)
				uassert.Equal(t, "foo:bar:500", pool.PoolPath())
				uassert.Equal(t, int64(20), pool.LastUnclaimableTime())
				uassert.Equal(t, int64(30), pool.UnclaimableAcc())
			},
		},
		{
			name: "GetIncentive",
			setup: func(m *MockStaker) { incentive := newExternalIncentive(); m.Response.Set("GetIncentive", &incentive) },
			getter: func() any { return GetIncentive("foo:bar:500", "incentive-1") },
			mutate: func(result any) {
				incentive := result.(*ExternalIncentive)
				incentive.SetRewardToken("mutated")
				incentive.SetRewardAmount(2000)
				incentive.SetRewardPerSecond(3000)
				incentive.SetDistributedRewardAmount(4000)
				incentive.SetRefunded(true)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				incentive := m.Response.data["GetIncentive"][0].(*ExternalIncentive)
				uassert.Equal(t, "reward-token", incentive.RewardToken())
				uassert.Equal(t, int64(1000), incentive.RewardAmount())
				uassert.Equal(t, int64(100), incentive.RewardPerSecond())
				uassert.Equal(t, int64(0), incentive.DistributedRewardAmount())
				uassert.Equal(t, false, incentive.Refunded())
			},
		},
		{
			name: "GetDeposit",
			setup: func(m *MockStaker) { m.Response.Set("GetDeposit", newStakerDeposit()) },
			getter: func() any { return GetDeposit(1) },
			mutate: func(result any) {
				deposit := result.(*Deposit)
				deposit.SetTargetPoolPath("mutated:pool")
				deposit.SetLiquidity(u256.MustFromDecimal("2000"))
				deposit.SetStakeTime(77)
				deposit.SetInternalRewardLastCollectTime(66)
				deposit.SetCollectedInternalReward(55)
				deposit.SetTickLower(-200)
				deposit.SetTickUpper(200)
				warmups := deposit.Warmups()
				warmups[0].WarmupRatio = 99
				deposit.SetWarmups(warmups)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				deposit := m.Response.data["GetDeposit"][0].(*Deposit)
				uassert.Equal(t, "foo:bar:500", deposit.TargetPoolPath())
				uassert.Equal(t, "1000", deposit.Liquidity().ToString())
				uassert.Equal(t, int64(10), deposit.StakeTime())
				uassert.Equal(t, int64(10), deposit.InternalRewardLastCollectTime())
				uassert.Equal(t, int64(40), deposit.CollectedInternalReward())
				uassert.Equal(t, int32(-100), deposit.TickLower())
				uassert.Equal(t, int32(100), deposit.TickUpper())
				uassert.Equal(t, uint64(30), deposit.Warmups()[0].WarmupRatio)
			},
		},
		{
			name: "GetDepositLiquidity",
			setup: func(m *MockStaker) { m.Response.Set("GetDepositLiquidity", u256.MustFromDecimal("1000")) },
			getter: func() any { return GetDepositLiquidity(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("2000")) },
			assertRaw: func(t *testing.T, m *MockStaker) {
				value := m.Response.data["GetDepositLiquidity"][0].(*u256.Uint)
				uassert.Equal(t, "1000", value.ToString())
			},
		},
		{
			name: "GetDepositWarmUp",
			setup: func(m *MockStaker) { m.Response.Set("GetDepositWarmUp", []Warmup{{Index: 0, TimeDuration: 10, NextWarmupTime: 20, WarmupRatio: 30}}) },
			getter: func() any { return GetDepositWarmUp(1) },
			mutate: func(result any) {
				warmups := result.([]Warmup)
				warmups[0].Index = 1
				warmups[0].TimeDuration = 99
				warmups[0].NextWarmupTime = 88
				warmups[0].WarmupRatio = 77
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				warmups := m.Response.data["GetDepositWarmUp"][0].([]Warmup)
				uassert.Equal(t, 0, warmups[0].Index)
				uassert.Equal(t, int64(10), warmups[0].TimeDuration)
				uassert.Equal(t, int64(20), warmups[0].NextWarmupTime)
				uassert.Equal(t, uint64(30), warmups[0].WarmupRatio)
			},
		},
		{
			name: "GetDepositExternalIncentiveIdList",
			setup: func(m *MockStaker) { m.Response.Set("GetDepositExternalIncentiveIdList", []string{"a", "b"}) },
			getter: func() any { return GetDepositExternalIncentiveIdList(1) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "c")
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetDepositExternalIncentiveIdList"][0].([]string)
				uassert.Equal(t, "a", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetExternalIncentiveByPoolPath",
			setup: func(m *MockStaker) { m.Response.Set("GetExternalIncentiveByPoolPath", []ExternalIncentive{newExternalIncentive()}) },
			getter: func() any { return GetExternalIncentiveByPoolPath("foo:bar:500") },
			mutate: func(result any) {
				values := result.([]ExternalIncentive)
				values[0].SetRewardToken("mutated")
				values[0].SetRewardAmount(2000)
				values[0].SetRewardPerSecond(3000)
				values[0].SetDistributedRewardAmount(4000)
				values[0].SetRefunded(true)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetExternalIncentiveByPoolPath"][0].([]ExternalIncentive)
				uassert.Equal(t, "reward-token", values[0].RewardToken())
				uassert.Equal(t, int64(1000), values[0].RewardAmount())
				uassert.Equal(t, int64(100), values[0].RewardPerSecond())
				uassert.Equal(t, int64(0), values[0].DistributedRewardAmount())
				uassert.Equal(t, false, values[0].Refunded())
			},
		},
		{
			name: "GetIncentiveRewardAmount",
			setup: func(m *MockStaker) { m.Response.Set("GetIncentiveRewardAmount", u256.MustFromDecimal("3000")) },
			getter: func() any { return GetIncentiveRewardAmount("foo:bar:500", "incentive-1") },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("4000")) },
			assertRaw: func(t *testing.T, m *MockStaker) {
				value := m.Response.data["GetIncentiveRewardAmount"][0].(*u256.Uint)
				uassert.Equal(t, "3000", value.ToString())
			},
		},
		{
			name: "GetPoolIncentiveIdList",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolIncentiveIdList", []string{"incentive-1", "incentive-2"}) },
			getter: func() any { return GetPoolIncentiveIdList("foo:bar:500") },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "incentive-3")
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolIncentiveIdList"][0].([]string)
				uassert.Equal(t, "incentive-1", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetPoolsByTier",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolsByTier", []string{"foo:bar:500", "baz:qux:3000"}) },
			getter: func() any { return GetPoolsByTier(1) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "new:pool:100")
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolsByTier"][0].([]string)
				uassert.Equal(t, "foo:bar:500", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetAllowedTokens",
			setup: func(m *MockStaker) { m.Response.Set("GetAllowedTokens", []string{"foo", "bar"}) },
			getter: func() any { return GetAllowedTokens() },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "baz")
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetAllowedTokens"][0].([]string)
				uassert.Equal(t, "foo", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetWarmupTemplate",
			setup: func(m *MockStaker) { m.Response.Set("GetWarmupTemplate", []Warmup{{Index: 0, TimeDuration: 10, NextWarmupTime: 20, WarmupRatio: 30}}) },
			getter: func() any { return GetWarmupTemplate() },
			mutate: func(result any) {
				warmups := result.([]Warmup)
				warmups[0].Index = 1
				warmups[0].TimeDuration = 99
				warmups[0].NextWarmupTime = 88
				warmups[0].WarmupRatio = 77
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				warmups := m.Response.data["GetWarmupTemplate"][0].([]Warmup)
				uassert.Equal(t, 0, warmups[0].Index)
				uassert.Equal(t, int64(10), warmups[0].TimeDuration)
				uassert.Equal(t, int64(20), warmups[0].NextWarmupTime)
				uassert.Equal(t, uint64(30), warmups[0].WarmupRatio)
			},
		},
		{
			name: "GetStakedPositionsByUser",
			setup: func(m *MockStaker) { m.Response.Set("GetStakedPositionsByUser", []uint64{1, 2}) },
			getter: func() any { return GetStakedPositionsByUser(adminAddr, 0, 10) },
			mutate: func(result any) {
				values := result.([]uint64)
				values[0] = 99
				_ = append(values, 100)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetStakedPositionsByUser"][0].([]uint64)
				uassert.Equal(t, uint64(1), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetPoolRewardCacheIDs",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolRewardCacheIDs", []int64{10, 20}) },
			getter: func() any { return GetPoolRewardCacheIDs("foo:bar:500", 0, 10) },
			mutate: func(result any) {
				values := result.([]int64)
				values[0] = 99
				_ = append(values, 100)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolRewardCacheIDs"][0].([]int64)
				uassert.Equal(t, int64(10), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetPoolIncentiveIDs",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolIncentiveIDs", []string{"one", "two"}) },
			getter: func() any { return GetPoolIncentiveIDs("foo:bar:500", 0, 10) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "three")
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolIncentiveIDs"][0].([]string)
				uassert.Equal(t, "one", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetPoolGlobalRewardRatioAccumulationIDs",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolGlobalRewardRatioAccumulationIDs", []uint64{10, 20}) },
			getter: func() any { return GetPoolGlobalRewardRatioAccumulationIDs("foo:bar:500", 0, 10) },
			mutate: func(result any) {
				values := result.([]uint64)
				values[0] = 99
				_ = append(values, 100)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolGlobalRewardRatioAccumulationIDs"][0].([]uint64)
				uassert.Equal(t, uint64(10), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name: "GetPoolGlobalRewardRatioAccumulation",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolGlobalRewardRatioAccumulation", u256.MustFromDecimal("5000")) },
			getter: func() any { return GetPoolGlobalRewardRatioAccumulation("foo:bar:500", 10) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("6000")) },
			assertRaw: func(t *testing.T, m *MockStaker) {
				value := m.Response.data["GetPoolGlobalRewardRatioAccumulation"][0].(*u256.Uint)
				uassert.Equal(t, "5000", value.ToString())
			},
		},
		{
			name: "GetPoolHistoricalTickIDs",
			setup: func(m *MockStaker) { m.Response.Set("GetPoolHistoricalTickIDs", []int32{-10, 10}) },
			getter: func() any { return GetPoolHistoricalTickIDs("foo:bar:500", 0, 10) },
			mutate: func(result any) {
				values := result.([]int32)
				values[0] = -99
				_ = append(values, 99)
			},
			assertRaw: func(t *testing.T, m *MockStaker) {
				values := m.Response.data["GetPoolHistoricalTickIDs"][0].([]int32)
				uassert.Equal(t, int32(-10), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			mockStaker := newMockStaker("v1")
			implementation = mockStaker
			tt.setup(mockStaker)
			result := tt.getter()
			tt.mutate(result)
			tt.assertRaw(t, mockStaker)
		})
	}
}

func TestCollectRewardIsolation(t *testing.T) {
	resetTestState(t)
	mockStaker := newMockStaker("v1")
	implementation = mockStaker
	storedInternalRewards := map[string]int64{"gns": 10}
	storedExternalRewards := map[string]int64{"bonus": 20}
	mockStaker.Response.Set("CollectReward", "pool", "100", storedInternalRewards, storedExternalRewards)

	poolPath, stakingDetails, internalRewards, externalRewards := CollectReward(cross, 1)

	uassert.Equal(t, "pool", poolPath)
	uassert.Equal(t, "100", stakingDetails)
	internalRewards["gns"] = 99
	internalRewards["new"] = 30
	externalRewards["bonus"] = 88
	externalRewards["new"] = 40

	uassert.Equal(t, int64(10), storedInternalRewards["gns"])
	_, ok := storedInternalRewards["new"]
	uassert.Equal(t, false, ok)
	uassert.Equal(t, int64(20), storedExternalRewards["bonus"])
	_, ok = storedExternalRewards["new"]
	uassert.Equal(t, false, ok)
}
