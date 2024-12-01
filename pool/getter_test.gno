package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestPoolGetPoolList(t *testing.T) {
	// Setup test pools
	pools = make(map[string]*Pool)
	poolList := PoolGetPoolList() // initial pool list is empty
	if len(poolList) != 0 {
		t.Errorf("Expected 0 pools, got %d", len(poolList))
	}

	pools["pool1"] = &Pool{}
	pools["pool2"] = &Pool{}

	poolList = PoolGetPoolList() // now pool list has 2 pools
	if len(poolList) != 2 {
		t.Errorf("Expected 2 pools, got %d", len(poolList))
	}

	// Check if all pools are included
	poolMap := make(map[string]bool)
	for _, path := range poolList {
		poolMap[path] = true
	}
	if !poolMap["pool1"] || !poolMap["pool2"] {
		t.Error("Pool list doesn't contain all expected pools")
	}
}

func TestPoolGetSlot0Tick(t *testing.T) {
	// Setup
	pools = make(map[string]*Pool)
	expectedTick := int32(500)
	pools["testPool"] = &Pool{
		slot0: Slot0{
			tick: expectedTick,
		},
	}

	// Test successful case
	tick := PoolGetSlot0Tick("testPool")
	if tick != expectedTick {
		t.Errorf("Expected tick %d, got %d", expectedTick, tick)
	}

	// Test non-existent pool
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic for non-existent pool")
		}
	}()
	PoolGetSlot0Tick("nonexistentPool")
}

func TestPoolGetSqrtPriceX96(t *testing.T) {
	// Setup
	pools = make(map[string]*Pool)
	expectedPrice := u256.NewUint(1000)
	pools["testPool"] = &Pool{
		slot0: Slot0{
			sqrtPriceX96: expectedPrice,
		},
	}

	// Test successful case
	price := PoolGetSqrtPriceX96("testPool")
	if !price.Eq(expectedPrice) {
		t.Errorf("Expected price %s, got %s", expectedPrice.ToString(), price.ToString())
	}

	// Test non-existent pool
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic for non-existent pool")
		}
	}()
	PoolGetSqrtPriceX96("nonexistentPool")
}

func TestPoolGetLiquidity(t *testing.T) {
	// Setup
	pools = make(map[string]*Pool)
	expectedLiquidity := u256.NewUint(2000)
	pools["testPool"] = &Pool{
		liquidity: expectedLiquidity,
	}

	// Test successful case
	liquidity := PoolGetLiquidity("testPool")
	if liquidity != expectedLiquidity.ToString() {
		t.Errorf("Expected liquidity %s, got %s", expectedLiquidity.ToString(), liquidity)
	}

	// Test non-existent pool
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic for non-existent pool")
		}
	}()
	PoolGetLiquidity("nonexistentPool")
}
