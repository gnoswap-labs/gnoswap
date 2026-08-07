package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	uassert "gno.land/p/nt/uassert/v0"
	sr "gno.land/r/gnoswap/staker"
)

func TestTicks(t *testing.T) {
	ticks := sr.NewTicks()

	// Get must not auto-insert: a missing tick returns nil and the tree stays empty.
	if tick := ticks.Get(100); tick != nil {
		t.Errorf("Get(100) returned %v; want nil for missing tick", tick)
	}
	uassert.False(t, ticks.Has(100))

	tick := sr.NewTick(100)
	tick.SetStakedLiquidityGross(u256.MustFromDecimal("1"))
	ticks.SetTick(100, tick)
	uassert.True(t, ticks.Has(100))

	if got := ticks.Get(100); got == nil || got.Id() != 100 {
		t.Errorf("Get(100) returned %v; want Tick with ID 100", got)
	}

	tick.SetStakedLiquidityGross(u256.Zero())
	ticks.SetTick(100, tick)
	uassert.False(t, ticks.Has(100))
}

func TestTicksBasic(t *testing.T) {
	ticks := sr.NewTicks()

	// Get must not auto-insert: a missing tick returns nil.
	if tick := ticks.Get(100); tick != nil {
		t.Errorf("Get(100) returned %v; want nil for missing tick", tick)
	}
	uassert.False(t, ticks.Has(100))

	tick100 := sr.NewTick(100)
	tick100.SetStakedLiquidityGross(u256.MustFromDecimal("1"))
	ticks.SetTick(100, tick100)
	uassert.True(t, ticks.Has(100))
	uassert.Equal(t, tick100.Id(), int32(100))

	tick100Again := ticks.Get(100)
	uassert.NotNil(t, tick100Again)
	uassert.Equal(t, int32(tick100Again.Id()), int32(tick100.Id()))
	uassert.False(t, tick100Again.StakedLiquidityGross().IsZero())
	uassert.True(t, tick100Again.StakedLiquidityDelta().IsZero())

	// Persisting a zero-gross tick prunes it from the tree.
	ticks.SetTick(100, sr.NewTick(100))
	uassert.False(t, ticks.Has(100))
}

func TestModifyDepositLower(t *testing.T) {
	tick := sr.NewTick(100)

	// initial value must be zero
	uassert.True(t, tick.StakedLiquidityGross().IsZero())
	uassert.True(t, tick.StakedLiquidityDelta().IsZero())

	// deposit +10
	liquidityDelta := i256.NewInt(10) // +10

	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositLower(50, liquidityDelta)

	// stakedLiquidityGross += +10 => 10
	// stakedLiquidityDelta += +10 => 10
	if tick.StakedLiquidityGross().ToString() != "10" || tick.StakedLiquidityDelta().ToString() != "10" {
		t.Errorf("After deposit +10, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,10",
			tick.StakedLiquidityGross(), tick.StakedLiquidityDelta())
	}

	// deposit another +5
	tickResolver.modifyDepositLower(60, i256.NewInt(5))
	// gross=15, delta=15
	if tickResolver.StakedLiquidityGross().ToString() != "15" || tickResolver.StakedLiquidityDelta().ToString() != "15" {
		t.Errorf("After deposit +5, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 15,15",
			tickResolver.StakedLiquidityGross(), tickResolver.StakedLiquidityDelta())
	}
}

func TestModifyDepositUpper(t *testing.T) {
	tick := sr.NewTick(200)

	// deposit +10 => modifyDepositUpper
	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositUpper(70, i256.NewInt(10))

	// stakedLiquidityGross=10, stakedLiquidityDelta = -10
	// 	upper => delta = stakedLiquidityDelta - liquidity
	if tickResolver.StakedLiquidityGross().ToString() != "10" || tickResolver.StakedLiquidityDelta().ToString() != "-10" {
		t.Errorf("After deposit +10(upper), stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,-10",
			tickResolver.StakedLiquidityGross(), tickResolver.StakedLiquidityDelta())
	}
}

func compareRangeSlices(t *testing.T, a, b [][2]uint64) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func compareInt64Slices(t *testing.T, a, b []int64) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// Test NewTickResolver
func TestNewTickResolver(t *testing.T) {
	tests := []struct {
		name   string
		tickID int32
	}{
		{
			name:   "create tick resolver for tick 100",
			tickID: 100,
		},
		{
			name:   "create tick resolver for tick -100",
			tickID: -100,
		},
		{
			name:   "create tick resolver for tick 0",
			tickID: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tick := sr.NewTick(tt.tickID)

			tickResolver := NewTickResolver(tick)

			uassert.NotNil(t, tickResolver)
			uassert.NotNil(t, tickResolver.Tick)
			uassert.Equal(t, tt.tickID, tick.Id())
		})
	}
}

// Test CurrentOutsideAccumulation
func TestCurrentOutsideAccumulation(t *testing.T) {
	tests := []struct {
		name           string
		tickID         int32
		setupFunc      func(*sr.Tick)
		queryTimestamp int64
		expectedIsZero bool
	}{
		{
			name:   "empty accumulation returns zero",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				// No setup - empty accumulation
			},
			queryTimestamp: 1000,
			expectedIsZero: true,
		},
		{
			name:   "single accumulation entry",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				tick.SetOutsideAccumulationAt(500, u256.NewUint(12345))
			},
			queryTimestamp: 1000,
			expectedIsZero: false,
		},
		{
			name:   "multiple accumulation entries",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				tick.SetOutsideAccumulationAt(100, u256.NewUint(1000))
				tick.SetOutsideAccumulationAt(500, u256.NewUint(5000))
				tick.SetOutsideAccumulationAt(1000, u256.NewUint(10000))
			},
			queryTimestamp: 1500,
			expectedIsZero: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tick := sr.NewTick(tt.tickID)

			if tt.setupFunc != nil {
				tt.setupFunc(tick)
			}

			tickResolver := NewTickResolver(tick)
			result := tickResolver.CurrentOutsideAccumulation(tt.queryTimestamp)

			uassert.NotNil(t, result)
			if tt.expectedIsZero {
				uassert.True(t, result.IsZero())
			} else {
				uassert.False(t, result.IsZero())
			}
		})
	}
}

// Test updateCurrentOutsideAccumulation
func TestUpdateCurrentOutsideAccumulation(t *testing.T) {
	tests := []struct {
		name         string
		tickID       int32
		currentAcc   *u256.Uint
		globalAcc    *u256.Uint
		timestamp    int64
		expectedDiff string
	}{
		{
			name:         "update with zero current accumulation",
			tickID:       100,
			currentAcc:   u256.Zero(),
			globalAcc:    u256.NewUint(1000),
			timestamp:    500,
			expectedDiff: "1000",
		},
		{
			name:         "update with non-zero current accumulation",
			tickID:       100,
			currentAcc:   u256.NewUint(300),
			globalAcc:    u256.NewUint(1000),
			timestamp:    500,
			expectedDiff: "700",
		},
		{
			name:         "update with equal accumulations",
			tickID:       100,
			currentAcc:   u256.NewUint(500),
			globalAcc:    u256.NewUint(500),
			timestamp:    500,
			expectedDiff: "0",
		},
		{
			name:         "update with underflow difference",
			tickID:       100,
			currentAcc:   u256.NewUint(600),
			globalAcc:    u256.NewUint(500),
			timestamp:    500,
			expectedDiff: "115792089237316195423570985008687907853269984665640564039457584007913129639836",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tick := sr.NewTick(tt.tickID)

			// Set up current accumulation
			if !tt.currentAcc.IsZero() {
				tick.SetOutsideAccumulationAt(tt.timestamp-100, tt.currentAcc)
			}

			tickResolver := NewTickResolver(tick)
			tickResolver.updateCurrentOutsideAccumulation(tt.timestamp, tt.globalAcc)

			// Verify the update
			newAcc := tickResolver.CurrentOutsideAccumulation(tt.timestamp)
			uassert.Equal(t, tt.expectedDiff, newAcc.ToString())
		})
	}
}

func TestTickCrossHook_BatchesNetZeroDeltaInitializedTick(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	instance := getMockInstance()
	poolPath := "test_pool"
	startTime := int64(1000)
	batchTime := int64(1010)
	liquidity := i256.NewInt(1000)

	pool := sr.NewPool(poolPath, startTime)
	poolResolver := NewPoolResolver(pool)
	poolResolver.modifyDeposit(liquidity, startTime, 5)

	tick := poolResolver.GetOrNewTick(10)
	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositUpper(startTime, liquidity)
	tickResolver.modifyDepositLower(startTime, liquidity)
	pool.Ticks().SetTick(10, tick)
	tick = pool.Ticks().Get(10)
	if tick.StakedLiquidityGross().IsZero() {
		t.Fatalf("tick 10 must remain initialized")
	}
	if !tick.StakedLiquidityDelta().IsZero() {
		t.Fatalf("tick 10 delta = %s, want 0", tick.StakedLiquidityDelta().ToString())
	}

	instance.getPools().set(poolPath, pool)
	instance.swapStartHook(0, cur, poolPath, batchTime)
	instance.tickCrossHook(0, cur, poolPath, 10, false, batchTime)

	batch := instance.store.GetCurrentSwapBatch()
	if batch == nil {
		t.Fatal("current swap batch not found")
	}
	crosses := batch.Crosses()
	if len(crosses) != 1 {
		t.Fatalf("batch crosses length = %d, want 1", len(crosses))
	}
	if crosses[0].TickID() != 10 {
		t.Fatalf("batch tick = %d, want 10", crosses[0].TickID())
	}
	if !crosses[0].Delta().IsZero() {
		t.Fatalf("batch delta = %s, want 0", crosses[0].Delta().ToString())
	}

	err := instance.swapEndHook(0, cur, poolPath)
	if err != nil {
		t.Fatalf("swapEndHook failed: %s", err.Error())
	}
	if instance.store.GetCurrentSwapBatch() != nil {
		t.Fatal("current swap batch must be cleared")
	}
	if poolResolver.CurrentTick(batchTime) != 10 {
		t.Fatalf("historical tick = %d, want 10", poolResolver.CurrentTick(batchTime))
	}
	if tickResolver.CurrentOutsideAccumulation(batchTime).IsZero() {
		t.Fatal("tick 10 outside accumulation was not updated")
	}
}

// TestTickCrossHook_DoesNotAutoInsertUninitializedTick verifies that crossing
// a tick that was never initialized by staking does not insert an empty tick
// into the pool's tick tree.
func TestTickCrossHook_DoesNotAutoInsertUninitializedTick(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	instance := getMockInstance()
	poolPath := "test_pool"
	startTime := int64(1000)
	batchTime := int64(1010)
	liquidity := i256.NewInt(1000)

	pool := sr.NewPool(poolPath, startTime)
	poolResolver := NewPoolResolver(pool)
	poolResolver.modifyDeposit(liquidity, startTime, 5)

	tick := poolResolver.GetOrNewTick(10)
	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositUpper(startTime, liquidity)
	tickResolver.modifyDepositLower(startTime, liquidity)
	pool.Ticks().SetTick(10, tick)

	instance.getPools().set(poolPath, pool)
	instance.swapStartHook(0, cur, poolPath, batchTime)
	if instance.store.GetCurrentSwapBatch() == nil {
		t.Fatal("current swap batch not found for pool with staked ticks")
	}

	// Crossing an uninitialized tick must not insert it into the pool's tick tree.
	instance.tickCrossHook(0, cur, poolPath, 999, false, batchTime)

	if pool.Ticks().Has(999) {
		t.Fatal("tickCrossHook auto-inserted uninitialized tick 999; tick state must not grow")
	}

	batch := instance.store.GetCurrentSwapBatch()
	if crosses := batch.Crosses(); len(crosses) != 0 {
		t.Fatalf("batch crosses length = %d, want 0 for uninitialized tick", len(crosses))
	}
}

// TestSwapStartHook_SkipsBatchForPoolWithoutStakedTicks verifies that the swap
// start hook does not persist a swap batch for a pool without any staked ticks,
// keeping swap hooks inactive on pools with no staking state.
func TestSwapStartHook_SkipsBatchForPoolWithoutStakedTicks(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	instance := getMockInstance()
	poolPath := "test_pool"
	startTime := int64(1000)

	// The mock store starts with a default inactive batch; capture it to detect
	// whether swapStartHook replaces it.
	before := instance.store.GetCurrentSwapBatch()

	// Pool is registered but never staked: its tick tree must be empty.
	pool := sr.NewPool(poolPath, startTime)
	instance.getPools().set(poolPath, pool)

	instance.swapStartHook(0, cur, poolPath, 1100)

	after := instance.store.GetCurrentSwapBatch()
	if after != before {
		t.Fatal("swapStartHook must not replace the swap batch for a pool without staked ticks")
	}
	if after.PoolPath() == poolPath {
		t.Fatal("swapStartHook must not create a swap batch for a pool without staked ticks")
	}
}

// TestProcessBatchedTickCrosses_SkipsPrunedTick verifies batch processing
// tolerates a tick removed between cross accumulation and batch processing.
// A pruned tick has zero staked gross liquidity and no reward weight, so it
// must be skipped rather than dereferenced.
func TestProcessBatchedTickCrosses_SkipsPrunedTick(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	instance := getMockInstance()
	poolPath := "test_pool"
	startTime := int64(1000)
	batchTime := int64(1010)
	liquidity := i256.NewInt(1000)

	pool := sr.NewPool(poolPath, startTime)
	poolResolver := NewPoolResolver(pool)
	poolResolver.modifyDeposit(liquidity, startTime, 5)

	tick := poolResolver.GetOrNewTick(10)
	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositUpper(startTime, liquidity)
	tickResolver.modifyDepositLower(startTime, liquidity)
	pool.Ticks().SetTick(10, tick)

	instance.getPools().set(poolPath, pool)
	instance.swapStartHook(0, cur, poolPath, batchTime)
	instance.tickCrossHook(0, cur, poolPath, 10, false, batchTime)

	batch := instance.store.GetCurrentSwapBatch()
	if crosses := batch.Crosses(); len(crosses) != 1 {
		t.Fatalf("batch crosses length = %d, want 1", len(crosses))
	}

	// Prune the tick after its cross was already accumulated.
	pool.Ticks().SetTick(10, sr.NewTick(10))
	uassert.False(t, pool.Ticks().Has(10))

	var hookErr error
	uassert.NotAborts(t, cur, func() {
		hookErr = instance.swapEndHook(0, cur, poolPath)
	})
	uassert.NoError(t, hookErr)
}

// TestBoundaryTicksOutliveTheirDeposits asserts a tick is pruned only once no
// deposit references it. Reward reads substitute a zero-valued tick when one is
// missing, so a live deposit whose boundary tick was pruned early would have
// its accumulated reward silently shifted.
func TestBoundaryTicksOutliveTheirDeposits(cur realm, t *testing.T) {
	initStakerTest(cur, t)

	startTime := int64(1000)
	liquidity := i256.NewInt(1000)
	pool := sr.NewPool("boundary-tick-pool", startTime)
	poolResolver := NewPoolResolver(pool)

	stake := func(tickLower, tickUpper int32, delta *i256.Int) {
		lower := poolResolver.GetOrNewTick(tickLower)
		NewTickResolver(lower).modifyDepositLower(startTime, delta)
		pool.Ticks().SetTick(tickLower, lower)

		upper := poolResolver.GetOrNewTick(tickUpper)
		NewTickResolver(upper).modifyDepositUpper(startTime, delta)
		pool.Ticks().SetTick(tickUpper, upper)
	}

	// Two deposits sharing the -10 boundary; unstaking one must keep it alive.
	stake(-10, 10, liquidity)
	stake(-10, 20, liquidity)
	uassert.True(t, pool.Ticks().Has(-10))

	stake(-10, 20, i256.Zero().Neg(liquidity))
	uassert.True(t, pool.Ticks().Has(-10), "shared boundary must survive a partial unstake")
	uassert.False(t, pool.Ticks().Has(20), "an unreferenced boundary must be pruned")
	uassert.NotNil(t, pool.Ticks().Get(-10))
	uassert.NotNil(t, pool.Ticks().Get(10))

	// One deposit's upper boundary is another's lower boundary.
	stake(10, 30, liquidity)
	stake(10, 30, i256.Zero().Neg(liquidity))
	uassert.True(t, pool.Ticks().Has(10), "boundary shared across roles must survive")

	// The last deposit leaves and both of its boundaries go.
	stake(-10, 10, i256.Zero().Neg(liquidity))
	uassert.False(t, pool.Ticks().Has(-10))
	uassert.False(t, pool.Ticks().Has(10))
	uassert.Equal(t, 0, pool.Ticks().Tree().Size())
}
