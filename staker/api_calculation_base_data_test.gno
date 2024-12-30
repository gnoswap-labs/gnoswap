package staker

import (
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