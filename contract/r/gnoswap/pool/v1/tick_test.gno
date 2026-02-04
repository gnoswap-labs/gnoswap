package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	pl "gno.land/r/gnoswap/pool"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestcalculateMaxLiquidityPerTick(t *testing.T) {
	tests := []struct {
		name        string
		tickSpacing int32
		want        string // expected result in string format
	}{
		{
			name:        "tick spacing 1 (for 0.01% pool)",
			tickSpacing: 1,
			want:        "191757530477355301479181766273477",
		},
		{
			name:        "tick spacing 10 (for 0.05% pool)",
			tickSpacing: 10,
			want:        "1917569901783203986719870431555990",
		},
		{
			name:        "tick spacing 60 (for 0.3% pool)",
			tickSpacing: 60,
			want:        "11505743598341114571880798222544994",
		},
		{
			name:        "tick spacing 200 (for 1% pool)",
			tickSpacing: 200,
			want:        "38350317471085141830651933667504588",
		},
		{
			name:        "entire range",
			tickSpacing: 887272,
			want:        "113427455640312821154458202477256070485",
		},
		{
			name:        "custom tick spacing",
			tickSpacing: 2302,
			want:        "441351967472034323558203122479595605",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculateMaxLiquidityPerTick(tt.tickSpacing)
			if got.ToString() != tt.want {
				t.Errorf("calculateMaxLiquidityPerTick() = %v, want %v", got.ToString(), tt.want)
			}
		})
	}
}

func TestCalculateFeeGrowthInside(t *testing.T) {
	// Create a mock pool
	pool := makeMockPool(createMockPoolParams{
		ticks: avl.NewTree(),
	})

	makeTickInfo := func(
		liquidityGross *u256.Uint,
		liquidityNet *i256.Int,
		feeGrowthOutside0X128 *u256.Uint,
		feeGrowthOutside1X128 *u256.Uint,
		initialized bool,
	) pl.TickInfo {
		tickInfo := pl.TickInfo{}
		tickInfo.SetLiquidityGross(liquidityGross)
		tickInfo.SetLiquidityNet(liquidityNet)
		tickInfo.SetFeeGrowthOutside0X128(feeGrowthOutside0X128)
		tickInfo.SetFeeGrowthOutside1X128(feeGrowthOutside1X128)
		tickInfo.SetInitialized(initialized)
		return tickInfo
	}

	// Setup test ticks
	pool.Ticks().Set("0", makeTickInfo(
		u256.NewUint(1000),
		i256.NewInt(100),
		u256.NewUint(5),
		u256.NewUint(7),
		true,
	))
	pool.Ticks().Set("100", makeTickInfo(
		u256.NewUint(2000),
		i256.NewInt(-100),
		u256.NewUint(10),
		u256.NewUint(15),
		true,
	))

	tests := []struct {
		name                 string
		tickLower            int32
		tickUpper            int32
		tickCurrent          int32
		feeGrowthGlobal0X128 *u256.Uint
		feeGrowthGlobal1X128 *u256.Uint
		want0                string
		want1                string
		preconditions        func()
	}{
		{
			name:                 "returns all for two uninitialized ticks if tick is inside",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          0,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "15",
			want1:                "15",
		},
		{
			name:                 "returns 0 for two uninitialized ticks if tick is above",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          4,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "0",
			want1:                "0",
		},
		{
			name:                 "returns 0 for two uninitialized ticks if tick is below",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          4,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "0",
			want1:                "0",
		},
		{
			name:                 "subtracts upper tick if below",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          0,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "13",
			want1:                "12",
			preconditions: func() {
				setMockPoolTick(pool, 2, mockTickInfo{
					feeGrowthOutside0X128: u256.NewUint(2),
					feeGrowthOutside1X128: u256.NewUint(3),
					liquidityGross:        u256.NewUint(0),
					liquidityNet:          i256.NewInt(0),
					initialized:           true,
				})
			},
		},
		{
			name:                 "subtracts lower tick if below",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          0,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "13",
			want1:                "12",
			preconditions: func() {
				deleteTick(pool, 2) // delete tick from previous test
				setMockPoolTick(pool, -2, mockTickInfo{
					feeGrowthOutside0X128: u256.NewUint(2),
					feeGrowthOutside1X128: u256.NewUint(3),
					liquidityGross:        u256.NewUint(0),
					liquidityNet:          i256.NewInt(0),
					initialized:           true,
				})
			},
		},
		{
			name:                 "subtracts upper and lower tick if inside",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          0,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "9",
			want1:                "11",
			preconditions: func() {
				setMockPoolTick(pool, 2, mockTickInfo{
					feeGrowthOutside0X128: u256.NewUint(4),
					feeGrowthOutside1X128: u256.NewUint(1),
					liquidityGross:        u256.NewUint(0),
					liquidityNet:          i256.NewInt(0),
					initialized:           true,
				})
			},
		},
		{
			name:                 "works correctly with overflow on inside tick",
			tickLower:            -2,
			tickUpper:            2,
			tickCurrent:          0,
			feeGrowthGlobal0X128: u256.NewUint(15),
			feeGrowthGlobal1X128: u256.NewUint(15),
			want0:                "16",
			want1:                "13",
			preconditions: func() {
				deleteTick(pool, 2)
				deleteTick(pool, -2)
				setMockPoolTick(pool, -2, mockTickInfo{
					feeGrowthOutside0X128: u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639932"), // max uint256 - 3
					feeGrowthOutside1X128: u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639933"), // max uint256 - 2
					liquidityGross:        u256.NewUint(0),
					liquidityNet:          i256.NewInt(0),
					initialized:           true,
				})
				setMockPoolTick(pool, 2, mockTickInfo{
					feeGrowthOutside0X128: u256.NewUint(3),
					feeGrowthOutside1X128: u256.NewUint(5),
					liquidityGross:        u256.NewUint(0),
					liquidityNet:          i256.NewInt(0),
					initialized:           true,
				})
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.preconditions != nil {
				tt.preconditions()
			}
			got0, got1 := getFeeGrowthInside(
				pool,
				tt.tickLower,
				tt.tickUpper,
				tt.tickCurrent,
				tt.feeGrowthGlobal0X128,
				tt.feeGrowthGlobal1X128,
			)
			if got0.ToString() != tt.want0 || got1.ToString() != tt.want1 {
				t.Errorf("getFeeGrowthInside() = (%v, %v), want (%v, %v)",
					got0.ToString(), got1.ToString(), tt.want0, tt.want1)
			}
		})
	}
}

func TestTickUpdate(t *testing.T) {
	pool := makeMockPool(createMockPoolParams{
		ticks: avl.NewTree(),
	})

	tests := []struct {
		name                 string
		preconditions        func()
		tick                 int32
		tickCurrent          int32
		liquidityDelta       *i256.Int
		feeGrowthGlobal0X128 *u256.Uint
		feeGrowthGlobal1X128 *u256.Uint
		upper                bool
		maxLiquidity         *u256.Uint
		wantFlipped          bool
		shouldPanic          bool
		verify               func()
	}{
		{
			name:                 "flips from zero to non zero",
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          true,
		},
		{
			name: "does not flip from nonzero to greater nonzero",
			preconditions: func() {
				deleteTick(pool, 0)
				tickUpdate(pool, 0, 0, i256.One(), u256.Zero(), u256.Zero(), false, u256.NewUint(3))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          false,
		},
		{
			name: "flips from nonzero to zero",
			preconditions: func() {
				deleteTick(pool, 0)
				tickUpdate(pool, 0, 0, i256.One(), u256.Zero(), u256.Zero(), false, u256.NewUint(3))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.NewInt(-1),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          true,
		},
		{
			name: "does not flip from nonzero to lesser nonzero",
			preconditions: func() {
				deleteTick(pool, 0)
				tickUpdate(pool, 0, 0, i256.NewInt(2), u256.Zero(), u256.Zero(), false, u256.NewUint(3))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.NewInt(-1),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          false,
		},
		{
			name: "reverts if total liquidity gross is greater than max",
			preconditions: func() {
				deleteTick(pool, 0)
				tickUpdate(pool, 0, 0, i256.NewInt(2), u256.Zero(), u256.Zero(), false, u256.NewUint(3))
				tickUpdate(pool, 0, 0, i256.One(), u256.Zero(), u256.Zero(), true, u256.NewUint(3))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          false,
			shouldPanic:          true,
		},
		{
			name: "nets the liquidity based on upper flag",
			preconditions: func() {
				tickUpdate(pool, 0, 0, i256.NewInt(2), u256.Zero(), u256.Zero(), false, u256.NewUint(10))
				tickUpdate(pool, 0, 0, i256.One(), u256.Zero(), u256.Zero(), true, u256.NewUint(10))
				tickUpdate(pool, 0, 0, i256.NewInt(3), u256.Zero(), u256.Zero(), true, u256.NewUint(10))
				tickUpdate(pool, 0, 0, i256.One(), u256.Zero(), u256.Zero(), false, u256.NewUint(10))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.NewUint(3),
			wantFlipped:          false,
			shouldPanic:          true,
		},
		{
			name: "reverts on overflow liquidity gross",
			preconditions: func() {
				tickUpdate(pool, 0, 0, i256.MustFromDecimal("170141183460469231731687303715884105726"), u256.Zero(), u256.Zero(), false, u256.MustFromDecimal("340282366920938463463374607431768211455"))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.MustFromDecimal("170141183460469231731687303715884105726"), // (maxUint128 / 2) + 1
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.MustFromDecimal("340282366920938463463374607431768211455"), // maxUint128
			wantFlipped:          false,
			shouldPanic:          true,
		},
		{
			name: "assumes all growth happens below ticks lte current tick",
			preconditions: func() {
				deleteTick(pool, 0)
				deleteTick(pool, 1)
				tickUpdate(pool, 1, 1, i256.One(), u256.One(), u256.NewUint(2), false, u256.MustFromDecimal("340282366920938463463374607431768211455"))
			},
			tick:                 0,
			tickCurrent:          0,
			liquidityDelta:       i256.MustFromDecimal("170141183460469231731687303715884105726"),
			feeGrowthGlobal0X128: u256.Zero(),
			feeGrowthGlobal1X128: u256.Zero(),
			upper:                false,
			maxLiquidity:         u256.MustFromDecimal("340282366920938463463374607431768211455"),
			wantFlipped:          false,
			shouldPanic:          false,
			verify: func() {
				info := getTick(pool, 1)
				uassert.Equal(t, info.FeeGrowthOutside0X128().ToString(), "1")
				uassert.Equal(t, info.FeeGrowthOutside1X128().ToString(), "2")
			},
		},
		{
			name: "does not set any growth fields if tick is already initialized",
			preconditions: func() {
				tickUpdate(pool, 1, 1, i256.One(), u256.One(), u256.NewUint(2), false, u256.MustFromDecimal("340282366920938463463374607431768211455"))
				tickUpdate(pool, 1, 1, i256.One(), u256.NewUint(6), u256.NewUint(7), false, u256.MustFromDecimal("340282366920938463463374607431768211455"))
			},
			tick:                 1,
			tickCurrent:          1,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.NewUint(6),
			feeGrowthGlobal1X128: u256.NewUint(7),
			upper:                false,
			maxLiquidity:         u256.MustFromDecimal("340282366920938463463374607431768211455"),
			wantFlipped:          false,
			shouldPanic:          false,
			verify: func() {
				info := getTick(pool, 1)
				uassert.Equal(t, info.FeeGrowthOutside0X128().ToString(), "1")
				uassert.Equal(t, info.FeeGrowthOutside1X128().ToString(), "2")
			},
		},
		{
			name:                 "does not set any growth fields for ticks gt current tick",
			tick:                 2,
			tickCurrent:          1,
			liquidityDelta:       i256.One(),
			feeGrowthGlobal0X128: u256.NewUint(1),
			feeGrowthGlobal1X128: u256.NewUint(2),
			upper:                false,
			maxLiquidity:         u256.MustFromDecimal("340282366920938463463374607431768211455"),
			wantFlipped:          false,
			shouldPanic:          false,
			verify: func() {
				info := getTick(pool, 2)
				uassert.Equal(t, info.FeeGrowthOutside0X128().ToString(), "0")
				uassert.Equal(t, info.FeeGrowthOutside1X128().ToString(), "0")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.preconditions != nil {
				tt.preconditions()
			}

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic, but got nil")
					}
				}()

				tickUpdate(pool,
					tt.tick,
					tt.tickCurrent,
					tt.liquidityDelta,
					tt.feeGrowthGlobal0X128,
					tt.feeGrowthGlobal1X128,
					tt.upper,
					tt.maxLiquidity,
				)
			} else {
				if tt.verify != nil {
					tt.verify()
				} else {
					gotFlipped := tickUpdate(pool,
						tt.tick,
						tt.tickCurrent,
						tt.liquidityDelta,
						tt.feeGrowthGlobal0X128,
						tt.feeGrowthGlobal1X128,
						tt.upper,
						tt.maxLiquidity,
					)
					if gotFlipped != tt.wantFlipped {
						t.Errorf("tickUpdate() flipped = %v, want %v", gotFlipped, tt.wantFlipped)
					}
				}
			}
		})
	}
}

func TestTickCross(t *testing.T) {
	pool := makeMockPool(createMockPoolParams{
		ticks: avl.NewTree(),
	})

	// Setup initial tick state

	tickInfo := mockTickInfo{
		liquidityGross:        u256.NewUint(1000),
		liquidityNet:          i256.NewInt(500),
		feeGrowthOutside0X128: u256.NewUint(10),
		feeGrowthOutside1X128: u256.NewUint(15),
		initialized:           true,
	}

	pool.Ticks().Set(pl.EncodeTickKey(100), tickInfo.toTickInfo())

	tests := []struct {
		name                 string
		tick                 int32
		feeGrowthGlobal0X128 *u256.Uint
		feeGrowthGlobal1X128 *u256.Uint
		wantLiquidityNet     string
	}{
		{
			name:                 "cross tick upwards",
			tick:                 100,
			feeGrowthGlobal0X128: u256.NewUint(20),
			feeGrowthGlobal1X128: u256.NewUint(25),
			wantLiquidityNet:     "500",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotLiquidityNet := tickCross(
				pool,
				tt.tick,
				tt.feeGrowthGlobal0X128,
				tt.feeGrowthGlobal1X128,
				u256.Zero(), // secondsPerLiquidityCumulativeX128
				int64(0),    // tickCumulative
				int64(0),    // blockTimestamp
			)
			if gotLiquidityNet.ToString() != tt.wantLiquidityNet {
				t.Errorf("tickCross() liquidityNet = %v, want %v",
					gotLiquidityNet.ToString(), tt.wantLiquidityNet)
			}
		})
	}
}

func TestGetTick(t *testing.T) {
	pool := &pl.Pool{}

	ticks := avl.NewTree()
	tickInfo := mockTickInfo{
		liquidityGross:        u256.NewUint(1000),
		liquidityNet:          i256.NewInt(500),
		feeGrowthOutside0X128: u256.NewUint(10),
		feeGrowthOutside1X128: u256.NewUint(15),
		initialized:           true,
	}
	ticks.Set(pl.EncodeTickKey(50), tickInfo.toTickInfo())

	pool.SetTicks(ticks)

	tests := []struct {
		name     string
		tick     int32
		wantInit bool
	}{
		{
			name:     "get existing tick",
			tick:     50,
			wantInit: true,
		},
		{
			name:     "get non-existing tick",
			tick:     100,
			wantInit: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := getTick(pool, tt.tick)
			if got.Initialized() != tt.wantInit {
				t.Errorf("getTick() initialized = %v, want %v", got.Initialized(), tt.wantInit)
			}
		})
	}
}

func TestGetFeeGrowthBelowX128(t *testing.T) {
	// Setup test data
	globalFeeGrowth0 := u256.NewUint(1000) // Global fee growth for token 0
	globalFeeGrowth1 := u256.NewUint(2000) // Global fee growth for token 1

	lowerTick := mockTickInfo{
		feeGrowthOutside0X128: u256.NewUint(300), // fee growth outside for token 0
		feeGrowthOutside1X128: u256.NewUint(500), // fee growth outside for token 1
	}

	tests := []struct {
		name               string
		tickLower          int32
		tickCurrent        int32
		expectedFeeGrowth0 *u256.Uint
		expectedFeeGrowth1 *u256.Uint
	}{
		{
			name:               "tickCurrent >= tickLower - Return feeGrowthOutside directly",
			tickLower:          100,
			tickCurrent:        100,
			expectedFeeGrowth0: lowerTick.feeGrowthOutside0X128,
			expectedFeeGrowth1: lowerTick.feeGrowthOutside1X128,
		},
		{
			name:               "tickCurrent > tickLower - Return feeGrowthOutside directly",
			tickLower:          50,
			tickCurrent:        100,
			expectedFeeGrowth0: lowerTick.feeGrowthOutside0X128,
			expectedFeeGrowth1: lowerTick.feeGrowthOutside1X128,
		},
		{
			name:               "tickCurrent < tickLower - Subtract feeGrowthOutside from global",
			tickLower:          100,
			tickCurrent:        50,
			expectedFeeGrowth0: u256.NewUint(700),  // 1000 - 300
			expectedFeeGrowth1: u256.NewUint(1500), // 2000 - 500
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Call the function
			feeGrowth0, feeGrowth1 := getFeeGrowthBelowX128(
				tt.tickLower, tt.tickCurrent,
				globalFeeGrowth0, globalFeeGrowth1,
				lowerTick.toTickInfo(),
			)

			// Assertions
			uassert.True(t, feeGrowth0.Eq(tt.expectedFeeGrowth0),
				"Expected feeGrowth0: %s, got: %s", tt.expectedFeeGrowth0.ToString(), feeGrowth0.ToString())
			uassert.True(t, feeGrowth1.Eq(tt.expectedFeeGrowth1),
				"Expected feeGrowth1: %s, got: %s", tt.expectedFeeGrowth1.ToString(), feeGrowth1.ToString())
		})
	}
}

func TestGetFeeGrowthAboveX128(t *testing.T) {
	// Setup test data
	globalFeeGrowth0 := u256.NewUint(1000) // Global fee growth for token 0
	globalFeeGrowth1 := u256.NewUint(2000) // Global fee growth for token 1

	upperTick := mockTickInfo{
		feeGrowthOutside0X128: u256.NewUint(300), // Fee growth outside for token 0
		feeGrowthOutside1X128: u256.NewUint(500), // Fee growth outside for token 1
	}

	tests := []struct {
		name               string
		tickUpper          int32
		tickCurrent        int32
		expectedFeeGrowth0 *u256.Uint
		expectedFeeGrowth1 *u256.Uint
	}{
		{
			name:               "tickCurrent < tickUpper - Return feeGrowthOutside directly",
			tickUpper:          100,
			tickCurrent:        50,
			expectedFeeGrowth0: upperTick.feeGrowthOutside0X128, // 300
			expectedFeeGrowth1: upperTick.feeGrowthOutside1X128, // 500
		},
		{
			name:               "tickCurrent >= tickUpper - Subtract feeGrowthOutside from global",
			tickUpper:          100,
			tickCurrent:        150,
			expectedFeeGrowth0: u256.NewUint(700),  // 1000 - 300
			expectedFeeGrowth1: u256.NewUint(1500), // 2000 - 500
		},
		{
			name:               "tickCurrent == tickUpper - Subtract feeGrowthOutside from global",
			tickUpper:          100,
			tickCurrent:        100,
			expectedFeeGrowth0: u256.NewUint(700),  // 1000 - 300
			expectedFeeGrowth1: u256.NewUint(1500), // 2000 - 500
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Call the function
			feeGrowth0, feeGrowth1 := getFeeGrowthAboveX128(
				tt.tickUpper, tt.tickCurrent,
				globalFeeGrowth0, globalFeeGrowth1,
				upperTick.toTickInfo(),
			)

			// Assertions
			uassert.True(t, feeGrowth0.Eq(tt.expectedFeeGrowth0),
				"Expected feeGrowth0: %s, got: %s", tt.expectedFeeGrowth0.ToString(), feeGrowth0.ToString())
			uassert.True(t, feeGrowth1.Eq(tt.expectedFeeGrowth1),
				"Expected feeGrowth1: %s, got: %s", tt.expectedFeeGrowth1.ToString(), feeGrowth1.ToString())
		})
	}
}

func initTick(
	t *testing.T,
	pool *pl.Pool,
	tick int32,
	feeGrowthOutside0X128 *u256.Uint,
	feeGrowthOutside1X128 *u256.Uint,
	liquidityGross *u256.Uint,
	liquidityNet *i256.Int,
	secondsPerLiquidityOutsideX128 *u256.Uint,
	tickCumulativeOutside int64,
	secondsOutside uint32,
	initialized bool,
) {
	t.Helper()

	info := getTick(pool, tick)
	info.SetFeeGrowthOutside0X128(feeGrowthOutside0X128)
	info.SetFeeGrowthOutside1X128(feeGrowthOutside1X128)
	info.SetLiquidityGross(liquidityGross)
	info.SetLiquidityNet(liquidityNet)
	info.SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128)
	info.SetTickCumulativeOutside(tickCumulativeOutside)
	info.SetSecondsOutside(secondsOutside)
	info.SetInitialized(initialized)

	setTick(pool, tick, info)
}

type mockTickInfo struct {
	feeGrowthOutside0X128          *u256.Uint
	feeGrowthOutside1X128          *u256.Uint
	liquidityGross                 *u256.Uint
	liquidityNet                   *i256.Int
	secondsPerLiquidityOutsideX128 *u256.Uint
	tickCumulativeOutside          int64
	secondsOutside                 uint32
	initialized                    bool
}

func (t *mockTickInfo) toTickInfo() pl.TickInfo {
	tickInfo := pl.NewTickInfo()
	tickInfo.SetFeeGrowthOutside0X128(t.feeGrowthOutside0X128)
	tickInfo.SetFeeGrowthOutside1X128(t.feeGrowthOutside1X128)
	tickInfo.SetLiquidityGross(t.liquidityGross)
	tickInfo.SetLiquidityNet(t.liquidityNet)
	tickInfo.SetSecondsPerLiquidityOutsideX128(t.secondsPerLiquidityOutsideX128)
	tickInfo.SetTickCumulativeOutside(t.tickCumulativeOutside)
	tickInfo.SetSecondsOutside(t.secondsOutside)
	tickInfo.SetInitialized(t.initialized)
	return tickInfo
}

func setMockPoolTick(
	pool *pl.Pool,
	tick int32,
	tickInfo mockTickInfo,
) {
	info := getTick(pool, tick)
	info.SetFeeGrowthOutside0X128(tickInfo.feeGrowthOutside0X128)
	info.SetFeeGrowthOutside1X128(tickInfo.feeGrowthOutside1X128)
	info.SetLiquidityGross(tickInfo.liquidityGross)
	info.SetLiquidityNet(tickInfo.liquidityNet)
	info.SetSecondsPerLiquidityOutsideX128(tickInfo.secondsPerLiquidityOutsideX128)
	info.SetTickCumulativeOutside(tickInfo.tickCumulativeOutside)
	info.SetSecondsOutside(tickInfo.secondsOutside)
	info.SetInitialized(tickInfo.initialized)

	setTick(pool, tick, info)
}

func deleteMockPoolTick(pool *pl.Pool, tick int32) {
	deleteTick(pool, tick)
}

// TestValidateTicks tests tick validation with edge cases
func TestValidateTicks(t *testing.T) {
	tests := []struct {
		name        string
		tickLower   int32
		tickUpper   int32
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "valid ticks in range",
			tickLower:   -1000,
			tickUpper:   1000,
			shouldError: false,
		},
		{
			name:        "valid ticks at MIN/MAX boundaries",
			tickLower:   MIN_TICK,
			tickUpper:   MAX_TICK,
			shouldError: false,
		},
		{
			name:        "valid ticks near boundaries",
			tickLower:   MIN_TICK + 1,
			tickUpper:   MAX_TICK - 1,
			shouldError: false,
		},
		{
			name:        "tickLower below MIN_TICK",
			tickLower:   MIN_TICK - 1,
			tickUpper:   0,
			shouldError: true,
			errorMsg:    "tick out of range",
		},
		{
			name:        "tickUpper above MAX_TICK",
			tickLower:   0,
			tickUpper:   MAX_TICK + 1,
			shouldError: true,
			errorMsg:    "tick out of range",
		},
		{
			name:        "tickLower equals tickUpper",
			tickLower:   100,
			tickUpper:   100,
			shouldError: true,
			errorMsg:    "tick range invalid",
		},
		{
			name:        "tickLower > tickUpper",
			tickLower:   1000,
			tickUpper:   -1000,
			shouldError: true,
			errorMsg:    "tick range invalid",
		},
		{
			name:        "zero ticks",
			tickLower:   0,
			tickUpper:   100,
			shouldError: false,
		},
		{
			name:        "negative range valid",
			tickLower:   -1000,
			tickUpper:   -100,
			shouldError: false,
		},
		{
			name:        "tickLower at MIN, tickUpper at MAX",
			tickLower:   MIN_TICK,
			tickUpper:   MAX_TICK,
			shouldError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateTicks(tt.tickLower, tt.tickUpper)
			if tt.shouldError {
				uassert.NotNil(t, err, "Expected error but got none")
				if err != nil && tt.errorMsg != "" {
					uassert.True(t, len(err.Error()) > 0, "Error message should not be empty")
				}
			} else {
				uassert.Nil(t, err, "Expected no error but got: "+ufmt.Sprintf("%v", err))
			}
		})
	}
}

// TestTickBoundaries tests tick boundary constants
func TestTickBoundaries(t *testing.T) {
	t.Run("MIN_TICK constant", func(t *testing.T) {
		uassert.Equal(t, int32(-887272), MIN_TICK)
	})

	t.Run("MAX_TICK constant", func(t *testing.T) {
		uassert.Equal(t, int32(887272), MAX_TICK)
	})

	t.Run("MIN_TICK is negative of MAX_TICK", func(t *testing.T) {
		uassert.Equal(t, -MIN_TICK, MAX_TICK)
	})
}

// TestCheckTickSpacingWithPoolTicks tests tick spacing validation
func TestCheckTickSpacingWithPoolTicks(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		shouldPanic bool
	}{
		{
			name:        "MIN_TICK with spacing 1",
			tick:        MIN_TICK,
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "MAX_TICK with spacing 1",
			tick:        MAX_TICK,
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "MIN_TICK with spacing 10 (aligned)",
			tick:        -887270, // MIN_TICK rounded to nearest 10
			tickSpacing: 10,
			shouldPanic: false,
		},
		{
			name:        "MAX_TICK with spacing 10 (aligned)",
			tick:        887270, // MAX_TICK rounded to nearest 10
			tickSpacing: 10,
			shouldPanic: false,
		},
		{
			name:        "MIN_TICK with spacing 10 (not aligned)",
			tick:        MIN_TICK,
			tickSpacing: 10,
			shouldPanic: true,
		},
		{
			name:        "MAX_TICK with spacing 10 (not aligned)",
			tick:        MAX_TICK,
			tickSpacing: 10,
			shouldPanic: true,
		},
		{
			name:        "zero tick with any spacing",
			tick:        0,
			tickSpacing: 60,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t,
					ufmt.Sprintf("[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(%d) MOD tickSpacing(%d) != 0(%d)",
						tt.tick, tt.tickSpacing, tt.tick%tt.tickSpacing),
					func() {
						checkTickSpacing(tt.tick, tt.tickSpacing)
					})
			} else {
				uassert.NotPanics(t, func() {
					checkTickSpacing(tt.tick, tt.tickSpacing)
				})
			}
		})
	}
}
