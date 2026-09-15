package staker

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	sr "gno.land/r/gnoswap/staker"
)

func TestRenderShowsStoredStateAndConfiguration(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()
	store := instance.store.(*MockStakerStore)

	store.pools.Set("pool-1", true)
	store.deposits.Set("position-1", true)
	store.externalIncentives.Set("incentive-1", true)
	store.unstakedPositions.Set("position-2", true)
	store.totalEmissionSent = 456
	store.poolTierCurrentEmission = 123
	store.depositGnsAmount = 12_345_678
	store.minimumRewardAmount = 98_765
	store.poolTierCounts = [sr.AllTierCount]uint64{0, 2, 3, 4}
	store.poolTierRatio = sr.NewTierRatio(50, 30, 20)
	store.unstakingFee = 100
	store.warmupTemplate = []sr.Warmup{
		sr.NewWarmup(10, 0, 30),
		sr.NewWarmup(20, 0, 50),
		sr.NewWarmup(30, 0, 70),
		sr.NewWarmup(9223372036854775807, 0, 100),
	}

	rendered := instance.Render("")
	for _, want := range []string{
		"| Stored pool records | 1 |",
		"| Active staked-position records | 1 |",
		"| Stored external incentive records | 1 |",
		"| Unstaked checkpoint records | 1 |",
		"| Cumulative GNS emission sent (base units; 6 decimals) | 456 |",
		"| Cached GNS emission rate (base units/second; 6 decimals) | 123 |",
		"| Required GNS deposit (GNS base units; 6 decimals) | 12345678 |",
		"| Default minimum external incentive reward (reward-token base units) | 98765 |",
		"| Tier pool counts (tier 1 / tier 2 / tier 3) | 2 / 3 / 4 |",
		"| Tier reward split (tier 1 / tier 2 / tier 3; percent) | 50% / 30% / 20% |",
		"| 30% | 10 seconds |",
		"| 100% | unbounded |",
		"| Unstaking fee | 100 bps (maximum 1000 bps) |",
	} {
		uassert.True(t, strings.Contains(rendered, want))
	}
}

func TestRenderUnknownPathReturns404BeforeStateAccess(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()
	store := instance.store
	instance.store = nil
	defer func() { instance.store = store }()

	uassert.Equal(t, "404\n", instance.Render("unsupported"))
}
