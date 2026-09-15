package staker

import (
	"chain"
	"math"
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
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

	out := md.H1("Gnoswap Staker")
	out += md.Paragraph(
		"All GNS amounts use the token's six-decimal base units. External reward amounts use\n" +
			"the reward token's own base units.",
	)

	out += md.H2("Implementation")
	implementationTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/staker").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Staker operations halted", ufmt.Sprintf("%t", halt.IsHaltedStaker())},
		},
	}
	out += implementationTable.String()

	out += md.H2("Accounting and configuration")
	accountingTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Stored pool records", ufmt.Sprintf("%d", s.store.GetPools().Size())},
			{"Active staked-position records", ufmt.Sprintf("%d", s.store.GetDeposits().Size())},
			{"Stored external incentive records", ufmt.Sprintf("%d", s.store.GetExternalIncentives().Size())},
			{"Unstaked checkpoint records", ufmt.Sprintf("%d", s.store.GetUnstakedPositions().Size())},
			{"Cumulative GNS emission sent (base units; 6 decimals)", ufmt.Sprintf("%d", s.store.GetTotalEmissionSent())},
			{"Cached GNS emission rate (base units/second; 6 decimals)", ufmt.Sprintf("%d", s.store.GetPoolTierCurrentEmission())},
			{"Required GNS deposit (GNS base units; 6 decimals)", ufmt.Sprintf("%d", s.store.GetDepositGnsAmount())},
			{"Default minimum external incentive reward (reward-token base units)", ufmt.Sprintf("%d", s.store.GetMinimumRewardAmount())},
			{"Tier pool counts (tier 1 / tier 2 / tier 3)", ufmt.Sprintf("%d / %d / %d", tierCounts[1], tierCounts[2], tierCounts[3])},
			{"Tier reward split (tier 1 / tier 2 / tier 3; percent)", ufmt.Sprintf("%d%% / %d%% / %d%%", tierRatio.Tier1, tierRatio.Tier2, tierRatio.Tier3)},
			{"Unstaking fee", ufmt.Sprintf("%d bps (maximum %d bps)", s.store.GetUnstakingFee(), maxUnstakingFee)},
			{"Allowed external incentive durations", "90 / 180 / 365 days"},
		},
	}
	out += accountingTable.String()

	out += md.H2("Warmup stages")
	warmupTable := mdtable.Table{
		Headers: []string{"Reward share", "Duration per stage"},
	}
	for _, warmup := range s.store.GetWarmupTemplate() {
		duration := ufmt.Sprintf("%d seconds", warmup.TimeDuration)
		if warmup.TimeDuration == math.MaxInt64 {
			duration = "unbounded"
		}
		warmupTable.Append([]string{
			ufmt.Sprintf("%d%%", warmup.WarmupRatio),
			duration,
		})
	}
	out += warmupTable.String()

	return out
}
