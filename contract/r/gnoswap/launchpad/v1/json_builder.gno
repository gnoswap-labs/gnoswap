package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/onbloc/json"
	"gno.land/r/gnoswap/launchpad"
)

// projectStatsBuilder adds ProjectStats fields to JSON using pre-calculated stats.
// This avoids multiple iterations over tiers by using the aggregated ProjectStats.
func projectStatsBuilder(b *json.NodeBuilder, stats ProjectStats) *json.NodeBuilder {
	return b.
		WriteString("totalDeposit", formatInt(stats.TotalDepositAmount)).
		WriteString("actualDeposit", formatInt(stats.CurrentDepositAmount)).
		WriteString("totalParticipant", formatInt(stats.TotalDepositCount)).
		WriteString("actualParticipant", formatInt(stats.CurrentDepositCount)).
		WriteString("totalCollected", formatInt(stats.TotalCollectedAmount))
}

// refundInfoBuilder adds RefundInfo fields to JSON using pre-calculated stats.
func refundInfoBuilder(b *json.NodeBuilder, stats ProjectStats) *json.NodeBuilder {
	return b.
		WriteString("refundedAmount", formatInt(stats.RemainingAmount))
}

// TierBuilder adds Tier fields to JSON
func tierBuilder(b *json.NodeBuilder, prefix string, tier *launchpad.ProjectTier) *json.NodeBuilder {
	// Add tiers info
	b.WriteString(prefix+"Id", tier.ID())
	b.WriteString(prefix+"TierAmount", formatInt(tier.TotalDistributeAmount()))
	b.WriteString(prefix+"TierAmountPerSecondX128", tier.DistributeAmountPerSecondX128().ToString())
	b.WriteString(prefix+"Started", formatInt(tier.StartTime()))
	b.WriteString(prefix+"Ended", formatInt(tier.EndTime()))
	b.WriteString(prefix+"TotalDepositAmount", formatInt(tier.TotalDepositAmount()))
	b.WriteString(prefix+"ActualDepositAmount", formatInt(getTierCurrentDepositAmount(tier)))
	b.WriteString(prefix+"TotalParticipant", formatInt(tier.TotalDepositCount()))
	b.WriteString(prefix+"ActualParticipant", formatInt(getTierCurrentDepositCount(tier)))
	b.WriteString(prefix+"UserCollectedAmount", formatInt(tier.TotalCollectedAmount()))
	return b
}

// ProjectBuilder adds Project fields to JSON
func projectBuilder(b *json.NodeBuilder, project *launchpad.Project) *json.NodeBuilder {
	b.WriteString("name", project.Name())
	b.WriteString("tokenPath", project.TokenPath())
	b.WriteString("depositAmount", formatInt(project.DepositAmount()))
	b.WriteString("recipient", project.Recipient().String())

	conditionsToken := ""
	conditionsAmount := ""

	idx := 0
	for _, condition := range project.Conditions() {
		if idx > 0 {
			conditionsToken += ","
			conditionsAmount += ","
		}
		conditionsToken += condition.TokenPath()
		conditionsAmount += formatInt(condition.MinimumAmount())
		idx++
	}
	b.WriteString("conditionsToken", conditionsToken)
	b.WriteString("conditionsAmount", conditionsAmount)

	// Add time info
	b.WriteString("createdTime", formatInt(project.CreatedAt()))
	b.WriteString("startedTime", formatInt(getStandardTier(project).StartTime()))
	b.WriteString("endedTime", formatInt(getStandardTier(project).EndTime()))

	// Calculate stats once and use for refund info
	stats := getProjectStats(project)
	refundInfoBuilder(b, stats)

	return b
}

// DepositBuilder adds Deposit fields to JSON
func depositBuilder(b *json.NodeBuilder, deposit *launchpad.Deposit) *json.NodeBuilder {
	return b.
		WriteString("depositId", deposit.ID()).
		WriteString("projectId", deposit.ProjectID()).
		WriteString("tier", formatInt(deposit.Tier())).
		WriteString("depositor", deposit.Depositor().String()).
		WriteString("amount", formatInt(deposit.DepositAmount())).
		WriteString("depositHeight", formatInt(deposit.CreatedHeight())).
		WriteString("depositTime", formatInt(deposit.CreatedAt()))
}

// MetaBuilder adds metadata fields to JSON
func metaBuilder() *json.NodeBuilder {
	height := runtime.ChainHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", formatInt(height)).
		WriteString("now", formatInt(now))
}

// Marshals a JSON node to a string, panics if marshalling fails
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
