package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"
	"gno.land/r/gnoswap/launchpad"
)

// projectStatsBuilder adds ProjectStats fields to JSON
func projectStatsBuilder(b *json.NodeBuilder, project *launchpad.Project) *json.NodeBuilder {
	return b.
		WriteString("totalDeposit", ufmt.Sprintf("%d", getProjectTotalDepositAmount(project))).
		WriteString("actualDeposit", ufmt.Sprintf("%d", getProjectCurrentDepositAmount(project))).
		WriteString("totalParticipant", ufmt.Sprintf("%d", getProjectTotalDepositCount(project))).
		WriteString("actualParticipant", ufmt.Sprintf("%d", getProjectCurrentDepositCount(project))).
		WriteString("totalCollected", ufmt.Sprintf("%d", getProjectTotalCollectedAmount(project)))
}

// refundInfoBuilder adds RefundInfo fields to JSON
func refundInfoBuilder(b *json.NodeBuilder, project *launchpad.Project) *json.NodeBuilder {
	return b.
		WriteString("refundedAmount", ufmt.Sprintf("%d", getProjectRemainingAmount(project)))
}

// TierBuilder adds Tier fields to JSON
func tierBuilder(b *json.NodeBuilder, prefix string, tier *launchpad.ProjectTier) *json.NodeBuilder {
	// Add tiers info
	b.WriteString(prefix+"Id", tier.ID())
	b.WriteString(prefix+"TierAmount", ufmt.Sprintf("%d", tier.TotalDistributeAmount()))
	b.WriteString(prefix+"TierAmountPerSecondX128", tier.DistributeAmountPerSecondX128().ToString())
	b.WriteString(prefix+"Started", ufmt.Sprintf("%d", tier.StartTime()))
	b.WriteString(prefix+"Ended", ufmt.Sprintf("%d", tier.EndTime()))
	b.WriteString(prefix+"TotalDepositAmount", ufmt.Sprintf("%d", tier.TotalDepositAmount()))
	b.WriteString(prefix+"ActualDepositAmount", ufmt.Sprintf("%d", getTierCurrentDepositAmount(tier)))
	b.WriteString(prefix+"TotalParticipant", ufmt.Sprintf("%d", tier.TotalDepositCount()))
	b.WriteString(prefix+"ActualParticipant", ufmt.Sprintf("%d", getTierCurrentDepositCount(tier)))
	b.WriteString(prefix+"UserCollectedAmount", ufmt.Sprintf("%d", tier.TotalCollectedAmount()))
	return b
}

// ProjectBuilder adds Project fields to JSON
func projectBuilder(b *json.NodeBuilder, project *launchpad.Project) *json.NodeBuilder {
	b.WriteString("name", project.Name())
	b.WriteString("tokenPath", project.TokenPath())
	b.WriteString("depositAmount", ufmt.Sprintf("%d", project.DepositAmount()))
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
		conditionsAmount += ufmt.Sprintf("%d", condition.MinimumAmount())
		idx++
	}
	b.WriteString("conditionsToken", conditionsToken)
	b.WriteString("conditionsAmount", conditionsAmount)

	// Add time info
	b.WriteString("createdTime", ufmt.Sprintf("%d", project.CreatedAt()))
	b.WriteString("startedTime", ufmt.Sprintf("%d", getStandardTier(project).StartTime()))
	b.WriteString("endedTime", ufmt.Sprintf("%d", getStandardTier(project).EndTime()))

	// Add refund info
	refundInfoBuilder(b, project)

	return b
}

// DepositBuilder adds Deposit fields to JSON
func depositBuilder(b *json.NodeBuilder, deposit *launchpad.Deposit) *json.NodeBuilder {
	return b.
		WriteString("depositId", deposit.ID()).
		WriteString("projectId", deposit.ProjectID()).
		WriteString("tier", ufmt.Sprintf("%d", deposit.Tier())).
		WriteString("depositor", deposit.Depositor().String()).
		WriteString("amount", ufmt.Sprintf("%d", deposit.DepositAmount())).
		WriteString("depositHeight", ufmt.Sprintf("%d", deposit.CreatedHeight())).
		WriteString("depositTime", ufmt.Sprintf("%d", deposit.CreatedAt()))
}

// MetaBuilder adds metadata fields to JSON
func metaBuilder() *json.NodeBuilder {
	height := runtime.ChainHeight()
	now := time.Now().Unix()

	return json.Builder().
		WriteString("height", ufmt.Sprintf("%d", height)).
		WriteString("now", ufmt.Sprintf("%d", now))
}

// Marshals a JSON node to a string, panics if marshalling fails
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
