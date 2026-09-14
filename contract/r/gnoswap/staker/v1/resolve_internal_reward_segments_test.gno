package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

// ---- test helpers -------------------------------------------------------------------------------

type halvingPoint struct {
	at       int64
	emission int64
}

// newTestPoolTier builds a PoolTier whose halving schedule is controlled by the test.
func newTestPoolTier(poolPath string, tier uint64, counts [AllTierCount]uint64, halvings []halvingPoint) *PoolTier {
	membership := sr.NewBPTreeN(16)
	if tier > 0 {
		membership.Set(poolPath, tier)
	}
	ratio := TierRatioFromCounts(counts[Tier1], counts[Tier2], counts[Tier3])

	getHalvings := func(start, end int64) ([]int64, []int64, error) {
		ts := make([]int64, 0)
		em := make([]int64, 0)
		for _, h := range halvings {
			if h.at >= start && h.at < end {
				ts = append(ts, h.at)
				em = append(em, h.emission)
			}
		}
		return ts, em, nil
	}

	return NewPoolTierBy(membership, ratio, counts, 0, 0, func() (int64, error) { return 0, nil }, getHalvings)
}

// newLinearAccPool builds a pool with constant staked liquidity and one global-accumulation checkpoint at
// createTime, so the global accumulation grows linearly and an in-range position accrues predictable
// reward when a schedule is applied.
func newLinearAccPool(poolPath string, createTime, poolLiq int64) *PoolResolver {
	pool := sr.NewPool(poolPath, createTime)
	resolver := NewPoolResolver(pool)
	pool.SetStakedLiquidityAt(createTime, u256.NewUintFromInt64(poolLiq))
	pool.SetHistoricalTickAt(createTime, 0)
	pool.Ticks().Get(-10)
	pool.Ticks().Get(10)
	return resolver
}

func newInRangeDeposit(poolPath string, createTime, depLiq int64, warmupRatio uint64, warmupEnd int64) *sr.Deposit {
	return sr.NewDeposit(
		testutils.TestAddress("owner"),
		poolPath,
		u256.NewUintFromInt64(depLiq),
		createTime,
		int32(-10),
		int32(10),
		[]sr.Warmup{sr.NewWarmup(0, warmupEnd, warmupRatio)},
	)
}

func nonEmptySegments(segments []internalRewardSegment) []internalRewardSegment {
	out := make([]internalRewardSegment, 0, len(segments))
	for _, seg := range segments {
		if seg.start < seg.end {
			out = append(out, seg)
		}
	}
	return out
}

// ---- resolveInternalRewardSegments --------------------------------------------------------------

// resolveInternalRewardSegments must build the per-second rate schedule from persisted cache entries
// (historical) plus an on-the-fly halving split of the uncached tail, using the current tier ratio/count.
func TestResolveInternalRewardSegments(cur realm, t *testing.T) {
	const (
		createTime = int64(1000)
		endTime    = int64(1010)
		e0         = int64(1_000_000)
	)

	type cacheEntry struct {
		at   int64
		rate int64
	}
	tests := []struct {
		name     string
		cache    []cacheEntry
		tier     uint64
		counts   [AllTierCount]uint64
		halvings []halvingPoint
		start    int64
		end      int64
		want     []internalRewardSegment
	}{
		{
			name:   "empty window yields no segments",
			cache:  []cacheEntry{{createTime, e0}},
			tier:   Tier1,
			counts: [AllTierCount]uint64{0, 1, 0, 0},
			start:  createTime,
			end:    createTime,
			want:   []internalRewardSegment{},
		},
		{
			name:   "no halving: single tail segment at the base rate",
			cache:  []cacheEntry{{createTime, e0}},
			tier:   Tier1,
			counts: [AllTierCount]uint64{0, 1, 0, 0},
			start:  createTime,
			end:    endTime,
			want: []internalRewardSegment{
				{start: createTime, end: endTime, rewardPerSecond: e0},
			},
		},
		{
			name:     "one halving splits the tail",
			cache:    []cacheEntry{{createTime, e0}},
			tier:     Tier1,
			counts:   [AllTierCount]uint64{0, 1, 0, 0},
			halvings: []halvingPoint{{at: 1005, emission: 500_000}},
			start:    createTime,
			end:      endTime,
			want: []internalRewardSegment{
				{start: createTime, end: 1005, rewardPerSecond: e0},
				{start: 1005, end: endTime, rewardPerSecond: 500_000},
			},
		},
		{
			name:     "multiple halvings split the tail into three",
			cache:    []cacheEntry{{createTime, e0}},
			tier:     Tier1,
			counts:   [AllTierCount]uint64{0, 1, 0, 0},
			halvings: []halvingPoint{{at: 1003, emission: 500_000}, {at: 1007, emission: 250_000}},
			start:    createTime,
			end:      endTime,
			want: []internalRewardSegment{
				{start: createTime, end: 1003, rewardPerSecond: e0},
				{start: 1003, end: 1007, rewardPerSecond: 500_000},
				{start: 1007, end: endTime, rewardPerSecond: 250_000},
			},
		},
		{
			name:     "halving at the segment start only switches the rate",
			cache:    []cacheEntry{{createTime, e0}},
			tier:     Tier1,
			counts:   [AllTierCount]uint64{0, 1, 0, 0},
			halvings: []halvingPoint{{at: createTime, emission: 500_000}},
			start:    createTime,
			end:      endTime,
			want: []internalRewardSegment{
				{start: createTime, end: endTime, rewardPerSecond: 500_000},
			},
		},
		{
			name:   "de-tiered pool: single base segment (rate stays at cached value)",
			cache:  []cacheEntry{{createTime, 0}},
			tier:   0,
			counts: [AllTierCount]uint64{0, 0, 0, 0},
			start:  createTime,
			end:    endTime,
			want: []internalRewardSegment{
				{start: createTime, end: endTime, rewardPerSecond: 0},
			},
		},
		{
			name:     "tier with two pools halves the per-pool rate at halving",
			cache:    []cacheEntry{{createTime, e0}},
			tier:     Tier1,
			counts:   [AllTierCount]uint64{0, 2, 0, 0},
			halvings: []halvingPoint{{at: 1005, emission: 500_000}},
			start:    createTime,
			end:      endTime,
			want: []internalRewardSegment{
				{start: createTime, end: 1005, rewardPerSecond: e0},
				{start: 1005, end: endTime, rewardPerSecond: 250_000}, // 500000 * 100 / 100 / 2
			},
		},
		{
			name:   "historical cache entries drive the pre-tail portion",
			cache:  []cacheEntry{{createTime, e0}, {1005, 800_000}},
			tier:   Tier1,
			counts: [AllTierCount]uint64{0, 1, 0, 0},
			start:  createTime,
			end:    endTime,
			want: []internalRewardSegment{
				{start: createTime, end: 1005, rewardPerSecond: e0},
				{start: 1005, end: endTime, rewardPerSecond: 800_000},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			pool := sr.NewPool("test_pool", createTime)
			resolver := NewPoolResolver(pool)
			for _, e := range tt.cache {
				pool.SetRewardCacheAt(e.at, e.rate)
			}

			poolTier := newTestPoolTier("test_pool", tt.tier, tt.counts, tt.halvings)

			segments, err := resolver.resolveInternalRewardSegments(poolTier, "test_pool", tt.start, tt.end)
			uassert.NoError(t, err)
			got := nonEmptySegments(segments)

			uassert.Equal(t, len(tt.want), len(got))
			for i := range tt.want {
				uassert.Equal(t, tt.want[i].start, got[i].start)
				uassert.Equal(t, tt.want[i].end, got[i].end)
				uassert.Equal(t, tt.want[i].rewardPerSecond, got[i].rewardPerSecond)
			}
		})
	}
}

// Resolving from a materialized reward cache and from the emission halving schedule must yield the same
// schedule (and rewards), and resolving from emission must not write to the cache.
func TestResolveInternalRewardSegments_EmissionMatchesMaterializedCache(cur realm, t *testing.T) {
	const (
		createTime = int64(1000)
		halveTime  = int64(1005)
		endTime    = int64(1010)
		poolLiq    = int64(1000)
		depLiq     = int64(1000)
		emission0  = int64(1_000_000)
		emission1  = int64(500_000)
	)

	deposit := newInRangeDeposit("", createTime, depLiq, 100, endTime+1000)

	// A pool tier that reports the halving on the fly (used by the emission path).
	poolTier := newTestPoolTier("pool_emission", Tier1, [AllTierCount]uint64{0, 1, 0, 0},
		[]halvingPoint{{at: halveTime, emission: emission1}})

	// Reference: reward cache already contains the halving boundary entry.
	refResolver := newLinearAccPool("pool_ref", createTime, poolLiq)
	refResolver.Pool.SetRewardCacheAt(createTime, emission0)
	refResolver.Pool.SetRewardCacheAt(halveTime, emission1)
	refSegments, err := refResolver.resolveInternalRewardSegments(poolTier, "pool_ref", createTime, endTime)
	uassert.NoError(t, err)
	refRewards, refPenalties := refResolver.RewardStateOf(deposit).calculateInternalReward(refSegments)

	// Emission path: only the base entry is cached; the halving comes from the schedule.
	emResolver := newLinearAccPool("pool_emission", createTime, poolLiq)
	emResolver.Pool.SetRewardCacheAt(createTime, emission0)
	cacheSizeBefore := emResolver.Pool.RewardCache().Size()
	emSegments, err := emResolver.resolveInternalRewardSegments(poolTier, "pool_emission", createTime, endTime)
	uassert.NoError(t, err)
	emRewards, emPenalties := emResolver.RewardStateOf(deposit).calculateInternalReward(emSegments)
	cacheSizeAfter := emResolver.Pool.RewardCache().Size()

	// No cache write on the emission path.
	uassert.Equal(t, cacheSizeBefore, cacheSizeAfter)

	// Identical schedule.
	refNon := nonEmptySegments(refSegments)
	emNon := nonEmptySegments(emSegments)
	uassert.Equal(t, len(refNon), len(emNon))
	for i := range refNon {
		uassert.Equal(t, refNon[i].start, emNon[i].start)
		uassert.Equal(t, refNon[i].end, emNon[i].end)
		uassert.Equal(t, refNon[i].rewardPerSecond, emNon[i].rewardPerSecond)
	}

	// Identical rewards, and non-zero (the scenario exercises real accumulation).
	uassert.Equal(t, len(refRewards), len(emRewards))
	total := int64(0)
	for i := range refRewards {
		uassert.Equal(t, refRewards[i], emRewards[i])
		uassert.Equal(t, refPenalties[i], emPenalties[i])
		total += emRewards[i]
	}
	uassert.True(t, total > 0)
}

// ---- calculateInternalReward ---------------------------------------------------------------------

// calculateInternalReward applies a pre-resolved schedule: empty schedules produce nothing, warmup ratios
// are applied to the accrued reward, and multiple segments accumulate.
func TestCalculateInternalReward(cur realm, t *testing.T) {
	const (
		createTime = int64(1000)
		endTime    = int64(1010)
		poolLiq    = int64(1000)
		depLiq     = int64(1000)
		rate       = int64(1_000_000)
	)

	tests := []struct {
		name            string
		segments        []internalRewardSegment
		warmupRatio     uint64
		wantRewardZero  bool
		wantPenaltyZero bool
	}{
		{
			name:            "empty schedule yields zero reward and zero penalty",
			segments:        []internalRewardSegment{},
			warmupRatio:     100,
			wantRewardZero:  true,
			wantPenaltyZero: true,
		},
		{
			name:            "full-window 100% warmup: reward accrues with no penalty",
			segments:        []internalRewardSegment{{start: createTime, end: endTime, rewardPerSecond: rate}},
			warmupRatio:     100,
			wantRewardZero:  false,
			wantPenaltyZero: true,
		},
		{
			name:            "full-window 50% warmup: reward and penalty both accrue",
			segments:        []internalRewardSegment{{start: createTime, end: endTime, rewardPerSecond: rate}},
			warmupRatio:     50,
			wantRewardZero:  false,
			wantPenaltyZero: false,
		},
		{
			name: "split segments accumulate over the window",
			segments: []internalRewardSegment{
				{start: createTime, end: 1005, rewardPerSecond: rate},
				{start: 1005, end: endTime, rewardPerSecond: rate},
			},
			warmupRatio:     100,
			wantRewardZero:  false,
			wantPenaltyZero: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resolver := newLinearAccPool("test_pool", createTime, poolLiq)
			deposit := newInRangeDeposit("test_pool", createTime, depLiq, tt.warmupRatio, endTime+1000)

			rewards, penalties := resolver.RewardStateOf(deposit).calculateInternalReward(tt.segments)

			totalReward := int64(0)
			totalPenalty := int64(0)
			for i := range rewards {
				totalReward += rewards[i]
				totalPenalty += penalties[i]
			}

			if tt.wantRewardZero {
				uassert.Equal(t, int64(0), totalReward)
			} else {
				uassert.True(t, totalReward > 0)
			}
			if tt.wantPenaltyZero {
				uassert.Equal(t, int64(0), totalPenalty)
			} else {
				uassert.True(t, totalPenalty > 0)
			}
		})
	}
}
