package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/json"
	"gno.land/p/demo/uassert"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestGetPoolStakedLiquidityUpdates(t *testing.T) {
	pools = NewPools()
	
	t.Run("not exist pool", func(t *testing.T) {
		result := GetPoolStakedLiquidityUpdates("invalid_pool", 0, 100)
		if result != "" {
			t.Errorf("not exist pool should return empty string. got: %s", result)
		}
	})

	t.Run("valid pool", func(t *testing.T) {
		poolPath := "test_pool"
		pool := &Pool{
			stakedLiquidity: NewUintTree(),
		}
		pools.Set(poolPath, pool)

		testData := []struct {
			height uint64
			value  string
		}{
			{10, "1000"},
			{20, "2000"},
			{30, "3000"},
		}

		for _, td := range testData {
			pool.stakedLiquidity.Set(td.height, u256.MustFromDecimal(td.value))
		}

		result := GetPoolStakedLiquidityUpdates(poolPath, 0, 100)

		node, err := json.Unmarshal([]byte(result))
		if err != nil {
			uassert.NoError(t, err)
		}

		array, err := node.GetKey("")
		uassert.NoError(t, err)
		uassert.Equal(t, array.Size(), 3)

		expectedData := []struct {
			blockNumber string
			liquidity  string
		}{
			{"10", "1000"},
			{"20", "2000"},
			{"30", "3000"},
		}

		for i, expect := range expectedData {
			item := array.MustIndex(i)
			
			blockNum, err := item.MustKey("blockNumber").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, blockNum, expect.blockNumber)

			liquidity, err := item.MustKey("liquidity").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, liquidity, expect.liquidity)
		}
	})
}

func TestGetPoolRewardUpdates(t *testing.T) {
	pools = NewPools()
	
	t.Run("not exist pool", func(t *testing.T) {
		result := GetPoolRewardUpdates("invalid_pool", 0, 100)
		if result != "" {
			t.Errorf("not exist pool should return empty string. got: %s", result)
		}
	})

	t.Run("valid pool", func(t *testing.T) {
		poolPath := "test_pool"
		pool := &Pool{
			rewardCache: NewRewardCacheTree(),
		}
		pools.Set(poolPath, pool)

		testData := []struct {
			height uint64
			value  string
		}{
			{15, "500"},
			{25, "1500"},
			{35, "2500"},
		}

		for _, td := range testData {
			pool.rewardCache.Set(td.height, u256.MustFromDecimal(td.value))
		}

		result := GetPoolRewardUpdates(poolPath, 0, 100)

		node, err := json.Unmarshal([]byte(result))
		if err != nil {
			uassert.NoError(t, err)
		}

		array, err := node.GetKey("")
		uassert.NoError(t, err)
		uassert.Equal(t, array.Size(), 3)

		expectedData := []struct {
			blockNumber string
			reward     string
		}{
			{"15", "500"},
			{"25", "1500"},
			{"35", "2500"},
		}

		for i, expect := range expectedData {
			item := array.MustIndex(i)
			
			blockNum, err := item.MustKey("blockNumber").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, blockNum, expect.blockNumber)

			reward, err := item.MustKey("reward").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, reward, expect.reward)
		}
	})
}

func TestGetWarmUpPeriods(t *testing.T) {
	tests := []struct {
		name           string
		currentHeight  int64
		expectedOutput string
	}{
		{
			name:           "normal warm-up period",
			currentHeight:  100,
			expectedOutput: "30*STAKER*50*STAKER*70*STAKER*100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetWarmUpPeriods()
			uassert.Equal(t, result, tt.expectedOutput)
		})
	}
}

func TestGetWarmUpPeriodsWithModifiedTemplate(t *testing.T) {
	originalTemplate := make([]Warmup, len(warmupTemplate))
	copy(originalTemplate, warmupTemplate)

	defer func() {
		warmupTemplate = originalTemplate
	}()

	modifyWarmup(0, 1000)

	result := GetWarmUpPeriods()
	expected := "30*STAKER*50*STAKER*70*STAKER*100"

	uassert.Equal(t, result, expected)
}

func TestGetWarmUpPeriodsEdgeCases(t *testing.T) {
	tests := []struct {
		name           string
		expectedOutput string
	}{
		{
			name:           "test 1",
			expectedOutput: "30*STAKER*50*STAKER*70*STAKER*100",
		},
		{
			name:           "test 2",
			expectedOutput: "30*STAKER*50*STAKER*70*STAKER*100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetWarmUpPeriods()
			uassert.Equal(t, result, tt.expectedOutput)
		})
	}
}
