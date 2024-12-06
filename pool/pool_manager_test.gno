package pool

import (
	"std"
	"strings"
	"testing"

	"gno.land/r/gnoswap/v1/consts"
)

func TestPoolMapOperations(t *testing.T) {
	pm := make(poolMap)

	poolPath := "token0:token1:500"
	params := newPoolParams("token0", "token1", 500, "4295128740")
	pool := newPool(params)

	pm.Set(poolPath, pool)

	retrieved, exists := pm.Get(poolPath)
	if !exists {
		t.Error("Expected pool to exist")
	}
	if retrieved != pool {
		t.Error("Retrieved pool doesn't match original")
	}

	_, exists = pm.Get("nonexistent")
	if exists {
		t.Error("Expected pool to not exist")
	}
}

func TestNewPoolParams(t *testing.T) {
	params := newPoolParams(
		"token0",
		"token1",
		500,       // 0.05% fee
		"1000000", // example sqrt price
	)

	if params.Token0Path() != "token0" {
		t.Errorf("Expected token0Path to be 'token0', got %s", params.Token0Path())
	}

	if params.TickSpacing() != 10 { // 500 fee should have 10 tick spacing
		t.Errorf("Expected tick spacing 10, got %d", params.TickSpacing())
	}

	if !params.isInOrder() {
		t.Errorf("Expected token0Path(token0) < token1Path(token1)")
	}

	params = newPoolParams(
		consts.GNOT,
		"token1",
		500,
		"1000000",
	)
	token0, token1 := params.wrap()
	if token0 != consts.WRAPPED_WUGNOT {
		t.Errorf("Expected GNOT to be wrapped to WUGNOT")
	}

	params = newPoolParams(
		"token0",
		"token0",
		500,
		"1000000",
	)
	if !params.isSameTokenPath() {
		t.Errorf("Expected token0Path(token0) == token1Path(token0)")
	}
}

func TestGetPoolPath(t *testing.T) {
	path := GetPoolPath("tokenA", "tokenB", 500)
	expected := "tokenA:tokenB:500"
	if path != expected {
		t.Errorf("Expected path %s, got %s", expected, path)
	}

	path = GetPoolPath("tokenB", "tokenA", 500)
	if path != expected {
		t.Errorf("Expected tokens to be sorted, expected %s, got %s", expected, path)
	}
}

func TestTickSpacingMap(t *testing.T) {
	tests := []struct {
		fee         uint32
		tickSpacing int32
	}{
		{100, 1},     // 0.01%
		{500, 10},    // 0.05%
		{3000, 60},   // 0.3%
		{10000, 200}, // 1%
	}

	for _, tt := range tests {
		spacing := feeAmountTickSpacing.Get(tt.fee)
		if spacing != tt.tickSpacing {
			t.Errorf("For fee %d, expected tick spacing %d, got %d",
				tt.fee, tt.tickSpacing, spacing)
		}
	}
}

func TestCreatePool(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		fee         uint32
		sqrtPrice   string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:       "success - normal token pair",
			token0Path: "test/token0",
			token1Path: "test/token1",
			fee:        3000,
			sqrtPrice:  "4295128740",
		},
		{
			name:        "fail - same tokens",
			token0Path:  "test/token0",
			token1Path:  "test/token0",
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-011] same token used in single pool || pool_manager.gno__CreatePool() || expected token0Path(test/token0) != token1Path(test/token0",
		},
		{
			name:        "fail - tokens not in order",
			token0Path:  "test/tokenB",
			token1Path:  "test/tokenA",
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-012] tokens must be in lexicographical order || pool_manager.gno__CreatePool() || expected token0Path(test/tokenB) < token1Path(test/tokenA)",
		},
		{
			name:        "fail - pool already exists",
			token0Path:  "test/token0",
			token1Path:  "test/token1",
			fee:         3000,
			sqrtPrice:   "4295128740",
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-013] pool already created || pool_manager.gno__CreatePool() || expected poolPath(test/token0:test/token1:3000) not to exist",
		},
	}

	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	SetPoolCreationFeeByAdmin(0)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}
					errMsg := string(r)
					if !strings.Contains(errMsg, tt.panicMsg) {
						t.Errorf("expected panic message containing %q but got %q", tt.panicMsg, errMsg)
					}
				}()
			}

			CreatePool(tt.token0Path, tt.token1Path, tt.fee, tt.sqrtPrice)

			if !tt.shouldPanic {
				// verify pool was created correctly
				poolPath := GetPoolPath(tt.token0Path, tt.token1Path, tt.fee)
				pool, exists := pools.Get(poolPath)
				if !exists {
					t.Errorf("pool was not created")
					return
				}

				// check if GNOT was properly wrapped
				expectedToken0 := tt.token0Path
				expectedToken1 := tt.token1Path
				if expectedToken0 == consts.GNOT {
					expectedToken0 = consts.WRAPPED_WUGNOT
				}
				if expectedToken1 == consts.GNOT {
					expectedToken1 = consts.WRAPPED_WUGNOT
				}

				if pool.token0Path != expectedToken0 || pool.token1Path != expectedToken1 {
					t.Errorf("incorrect token paths in pool. got %s,%s want %s,%s",
						pool.token0Path, pool.token1Path, expectedToken0, expectedToken1)
				}
			}
		})
	}
}
