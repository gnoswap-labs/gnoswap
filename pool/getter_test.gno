package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestPoolGetters(t *testing.T) {
	// Setup test data
	testPool := &Pool{
		token0Path: "token0/path",
		token1Path: "token1/path",
		fee:        3000,
		slot0: Slot0{
			sqrtPriceX96: u256.NewUint(2000),
			tick:         5,
		},
		liquidity:            u256.NewUint(1000),
		feeGrowthGlobal0X128: u256.NewUint(500),
		feeGrowthGlobal1X128: u256.NewUint(600),
	}

	// Add test position
	testPositionKey := "test_position"
	testPool.positions = map[string]PositionInfo{
		testPositionKey: {
			feeGrowthInside0LastX128: u256.NewUint(100),
			feeGrowthInside1LastX128: u256.NewUint(200),
		},
	}

	// Add test tick
	testTickIndex := int32(10)
	testPool.ticks = map[int32]TickInfo{
		testTickIndex: {
			feeGrowthOutside0X128: u256.NewUint(300),
			feeGrowthOutside1X128: u256.NewUint(400),
		},
	}

	// Add pool to global pools map
	testPoolPath := "test/pool/path"
	pools = map[string]*Pool{
		testPoolPath: testPool,
	}

	// Test global getters
	t.Run("PoolGetPoolList", func(t *testing.T) {
		poolList := PoolGetPoolList()
		if len(poolList) != 1 || poolList[0] != testPoolPath {
			t.Errorf("Expected pool list [%s], got %v", testPoolPath, poolList)
		}
	})

	t.Run("PoolGetSlot0Tick", func(t *testing.T) {
		tick := PoolGetSlot0Tick(testPoolPath)
		if tick != 5 {
			t.Errorf("Expected tick 5, got %d", tick)
		}
	})

	t.Run("PoolGetSqrtPriceX96", func(t *testing.T) {
		price := PoolGetSqrtPriceX96(testPoolPath)
		if !price.Eq(u256.NewUint(2000)) {
			t.Errorf("Expected price 2000, got %s", price.ToString())
		}
	})

	t.Run("PoolGetLiquidity", func(t *testing.T) {
		liquidity := PoolGetLiquidity(testPoolPath)
		if liquidity != "1000" {
			t.Errorf("Expected liquidity 1000, got %s", liquidity)
		}
	})

	// Test pool instance getters
	t.Run("Pool instance getters", func(t *testing.T) {
		if got := testPool.PoolGetSlot0SqrtPriceX96(); got.ToString() != "2000" {
			t.Errorf("PoolGetSlot0SqrtPriceX96: expected 2000, got %s", got.ToString())
		}

		if got := testPool.PoolGetSlot0Tick(); got != 5 {
			t.Errorf("PoolGetSlot0Tick: expected 5, got %d", got)
		}

		if got := testPool.PoolGetPositionFeeGrowthInside0LastX128(testPositionKey); !got.Eq(u256.NewUint(100)) {
			t.Errorf("PoolGetPositionFeeGrowthInside0LastX128: expected 100, got %s", got.ToString())
		}

		if got := testPool.PoolGetPositionFeeGrowthInside1LastX128(testPositionKey); !got.Eq(u256.NewUint(200)) {
			t.Errorf("PoolGetPositionFeeGrowthInside1LastX128: expected 200, got %s", got.ToString())
		}

		if got := testPool.PoolGetTickFeeGrowthOutside0X128(testTickIndex); !got.Eq(u256.NewUint(300)) {
			t.Errorf("PoolGetTickFeeGrowthOutside0X128: expected 300, got %s", got.ToString())
		}

		if got := testPool.PoolGetTickFeeGrowthOutside1X128(testTickIndex); !got.Eq(u256.NewUint(400)) {
			t.Errorf("PoolGetTickFeeGrowthOutside1X128: expected 400, got %s", got.ToString())
		}

		if got := testPool.PoolGetToken0Path(); got != "token0/path" {
			t.Errorf("PoolGetToken0Path: expected token0/path, got %s", got)
		}

		if got := testPool.PoolGetToken1Path(); got != "token1/path" {
			t.Errorf("PoolGetToken1Path: expected token1/path, got %s", got)
		}

		if got := testPool.PoolGetFee(); got != 3000 {
			t.Errorf("PoolGetFee: expected 3000, got %d", got)
		}

		if got := testPool.PoolGetFeeGrowthGlobal0X128(); !got.Eq(u256.NewUint(500)) {
			t.Errorf("PoolGetFeeGrowthGlobal0X128: expected 500, got %s", got.ToString())
		}

		if got := testPool.PoolGetFeeGrowthGlobal1X128(); !got.Eq(u256.NewUint(600)) {
			t.Errorf("PoolGetFeeGrowthGlobal1X128: expected 600, got %s", got.ToString())
		}

		if got := testPool.PoolGetLiquidity(); !got.Eq(u256.NewUint(1000)) {
			t.Errorf("PoolGetLiquidity: expected 1000, got %s", got.ToString())
		}
	})

	// Test non-existent pool/position/tick cases
	t.Run("Non-existent cases", func(t *testing.T) {
		if got := testPool.PoolGetPositionFeeGrowthInside0LastX128("non_existent"); !got.Eq(u256.Zero()) {
			t.Errorf("Expected zero for non-existent position, got %s", got.ToString())
		}

		if got := testPool.PoolGetTickFeeGrowthOutside0X128(999); !got.Eq(u256.Zero()) {
			t.Errorf("Expected zero for non-existent tick, got %s", got.ToString())
		}
	})
}
