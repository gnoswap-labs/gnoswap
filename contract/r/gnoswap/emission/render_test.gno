package emission

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRenderFormatsEmissionState(cur realm, t *testing.T) {
	resetObject(t)
	defer resetObject(t)

	distributionStartTimestamp = 1_700_000_000
	lastExecutedTimestamp = 1_700_000_001
	leftGNSAmount = 1
	distributedToStaker = 1_000_000
	distributedToDevOps = 1_234_567
	distributedToCommunityPool = 100
	distributedToGovStaker = 10_000_000
	accuDistributedToStaker = 2_000_000
	accuDistributedToDevOps = 3_000_000
	accuDistributedToCommunityPool = 4_000_000
	accuDistributedToGovStaker = 5_000_000
	distributionBpsPct = map[int]int64{
		LIQUIDITY_STAKER: 1,
		DEVOPS:           99,
		COMMUNITY_POOL:   9900,
		GOV_STAKER:       0,
	}

	rendered := Render("")

	uassert.True(t, strings.Contains(rendered, "| Distribution start | 2023-11-14T22:13:20Z |"))
	uassert.True(t, strings.Contains(rendered, "| Last execution | 2023-11-14T22:13:21Z |"))
	uassert.True(t, strings.Contains(rendered, "| Undistributed GNS | 0.000001 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Total cumulative distributed | 14.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Liquidity stakers | 0.01% | 2.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| DevOps | 0.99% | 3.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Community pool | 99.00% | 4.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Governance stakers | 0.00% | 5.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Liquidity stakers | 1.000000 GNS |"))
	uassert.True(t, strings.Contains(rendered, "| Governance stakers | 10.000000 GNS |"))
	uassert.False(t, strings.Contains(rendered, "| DevOps | 0.99% | 1.234567 GNS |"))
	uassert.False(t, strings.Contains(rendered, "| Community pool | 99.00% | 0.000100 GNS |"))
}

func TestRenderFormatsDistributionPercentageBoundaries(cur realm, t *testing.T) {
	resetObject(t)
	defer resetObject(t)

	distributionBpsPct = map[int]int64{
		LIQUIDITY_STAKER: 9999,
		DEVOPS:           0,
		COMMUNITY_POOL:   0,
		GOV_STAKER:       1,
	}
	rendered := Render("")
	uassert.True(t, strings.Contains(rendered, "| Liquidity stakers | 99.99% |"))
	uassert.True(t, strings.Contains(rendered, "| Governance stakers | 0.01% |"))

	distributionBpsPct = map[int]int64{
		LIQUIDITY_STAKER: 10000,
		DEVOPS:           0,
		COMMUNITY_POOL:   0,
		GOV_STAKER:       0,
	}
	rendered = Render("")
	uassert.True(t, strings.Contains(rendered, "| Liquidity stakers | 100.00% |"))
}

func TestRenderUsesSemanticZeroTimestamps(cur realm, t *testing.T) {
	resetObject(t)
	defer resetObject(t)

	rendered := Render("")

	uassert.True(t, strings.Contains(rendered, "| Distribution start | Not started |"))
	uassert.True(t, strings.Contains(rendered, "| Distribution end | Not scheduled |"))
	uassert.True(t, strings.Contains(rendered, "| Last execution | Not yet executed |"))
	uassert.False(t, strings.Contains(rendered, "1970-01-01"))
}

func TestRenderUnknownPath(cur realm, t *testing.T) {
	resetObject(t)
	defer resetObject(t)

	uassert.Equal(t, "404\n", Render("history"))
}
