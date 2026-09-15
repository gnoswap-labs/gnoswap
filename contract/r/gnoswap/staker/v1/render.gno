package staker

import (
	"chain"
	"math"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt/v1"
	stakerRoot "gno.land/r/gnoswap/staker"
)

func (s *stakerV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	tierCounts := s.store.GetPoolTierCounts()
	tierRatio := s.store.GetPoolTierRatio()
	implementation := stakerRoot.GetImplementationPackagePath()

	return ufmt.Sprintf(
		`# Gnoswap Staker

All GNS amounts use the token's six-decimal base units. External reward amounts use
the reward token's own base units.

## Implementation

| Field | Value |
| --- | --- |
| Realm address | `+"`%s`"+` |
| Active implementation | [%s](%s) |
| Staker operations halted | %t |

## Accounting and configuration

| Field | Value |
| --- | --- |
| Stored pool records | %d |
| Active staked-position records | %d |
| Stored external incentive records | %d |
| Unstaked checkpoint records | %d |
| Cumulative GNS emission sent (base units; 6 decimals) | %d |
| Cached GNS emission rate (base units/second; 6 decimals) | %d |
| Required GNS deposit (GNS base units; 6 decimals) | %d |
| Default minimum external incentive reward (reward-token base units) | %d |
| Tier pool counts (tier 1 / tier 2 / tier 3) | %d / %d / %d |
| Tier reward split (tier 1 / tier 2 / tier 3; percent) | %d%% / %d%% / %d%% |
| Unstaking fee | %d bps (maximum %d bps) |
| Allowed external incentive durations | 90 / 180 / 365 days |

## Warmup stages

| Reward share | Duration per stage |
| --- | --- |
%s
`,
		chain.PackageAddress("gno.land/r/gnoswap/staker"),
		implementation,
		strings.TrimPrefix(implementation, "gno.land"),
		halt.IsHaltedStaker(),
		s.store.GetPools().Size(),
		s.store.GetDeposits().Size(),
		s.store.GetExternalIncentives().Size(),
		s.store.GetUnstakedPositions().Size(),
		s.store.GetTotalEmissionSent(),
		s.store.GetPoolTierCurrentEmission(),
		s.store.GetDepositGnsAmount(),
		s.store.GetMinimumRewardAmount(),
		tierCounts[1],
		tierCounts[2],
		tierCounts[3],
		tierRatio.Tier1,
		tierRatio.Tier2,
		tierRatio.Tier3,
		s.store.GetUnstakingFee(),
		maxUnstakingFee,
		renderWarmupTemplate(s.store.GetWarmupTemplate()),
	)
}

func renderWarmupTemplate(warmups []stakerRoot.Warmup) string {
	result := ""
	for _, warmup := range warmups {
		duration := ufmt.Sprintf("%d seconds", warmup.TimeDuration)
		if warmup.TimeDuration == math.MaxInt64 {
			duration = "unbounded"
		}
		result += ufmt.Sprintf("| %d%% | %s |\n", warmup.WarmupRatio, duration)
	}
	return result
}
