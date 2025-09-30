package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/onbloc/json"
	"gno.land/p/nt/ufmt"
)

// projectStatsBuilder adds ProjectStats fields to JSON
func projectStatsBuilder(b *json.NodeBuilder, project *Project) *json.NodeBuilder {
	return b.
		WriteString("totalDeposit", ufmt.Sprintf("%d", project.TotalDepositAmount())).
		WriteString("actualDeposit", ufmt.Sprintf("%d", project.CurrentDepositAmount())).
		WriteString("totalParticipant", ufmt.Sprintf("%d", project.TotalDepositCount())).
		WriteString("actualParticipant", ufmt.Sprintf("%d", project.CurrentDepositCount())).
		WriteString("totalCollected", ufmt.Sprintf("%d", project.TotalCollectedAmount()))
}

// refundInfoBuilder adds RefundInfo fields to JSON
func refundInfoBuilder(b *json.NodeBuilder, project *Project) *json.NodeBuilder {
	return b.
		WriteString("refundedAmount", ufmt.Sprintf("%d", project.RemainingAmount()))
}

// TierBuilder adds Tier fields to JSON
func tierBuilder(b *json.NodeBuilder, prefix string, tier *ProjectTier) *json.NodeBuilder {
	// Add tiers info
	b.WriteString(prefix+"Id", tier.id)
	b.WriteString(prefix+"TierAmount", ufmt.Sprintf("%d", tier.TotalDistributeAmount()))
	b.WriteString(prefix+"TierAmountPerSecondX128", tier.DistributeAmountPerSecondX128().ToString())
	b.WriteString(prefix+"Started", ufmt.Sprintf("%d", tier.StartTime()))
	b.WriteString(prefix+"Ended", ufmt.Sprintf("%d", tier.EndTime()))
	b.WriteString(prefix+"TotalDepositAmount", ufmt.Sprintf("%d", tier.TotalDepositAmount()))
	b.WriteString(prefix+"ActualDepositAmount", ufmt.Sprintf("%d", tier.CurrentDepositAmount()))
	b.WriteString(prefix+"TotalParticipant", ufmt.Sprintf("%d", tier.TotalDepositCount()))
	b.WriteString(prefix+"ActualParticipant", ufmt.Sprintf("%d", tier.CurrentDepositCount()))
	b.WriteString(prefix+"UserCollectedAmount", ufmt.Sprintf("%d", tier.TotalCollectedAmount()))
	return b
}

// ProjectBuilder adds Project fields to JSON
func projectBuilder(b *json.NodeBuilder, project *Project) *json.NodeBuilder {
	b.WriteString("name", project.name)
	b.WriteString("tokenPath", project.tokenPath)
	b.WriteString("depositAmount", ufmt.Sprintf("%d", project.depositAmount))
	b.WriteString("recipient", project.recipient.String())

	tokenPaths := []string{}
	amounts := []string{}

	for _, condition := range project.getConditions() {
		tokenPaths = append(tokenPaths, condition.TokenPath())
		amounts = append(amounts, ufmt.Sprintf("%d", condition.MinimumAmount()))
	}
	b.WriteString("conditionsToken", strings.Join(tokenPaths, ","))
	b.WriteString("conditionsAmount", strings.Join(amounts, ","))

	// Add time info
	b.WriteString("createdTime", ufmt.Sprintf("%d", project.CreatedAt()))
	b.WriteString("startedTime", ufmt.Sprintf("%d", project.standardTier().StartTime()))
	b.WriteString("endedTime", ufmt.Sprintf("%d", project.standardTier().EndTime()))

	// Add refund info
	refundInfoBuilder(b, project)

	return b
}

// DepositBuilder adds Deposit fields to JSON
func depositBuilder(b *json.NodeBuilder, deposit *Deposit) *json.NodeBuilder {
	return b.
		WriteString("depositId", deposit.id).
		WriteString("projectId", deposit.ProjectID()).
		WriteString("tier", ufmt.Sprintf("%d", deposit.Tier())).
		WriteString("depositor", deposit.Depositor().String()).
		WriteString("amount", ufmt.Sprintf("%d", deposit.DepositAmount())).
		WriteString("depositHeight", ufmt.Sprintf("%d", deposit.CreatedHeight())).
		WriteString("depositTime", ufmt.Sprintf("%d", deposit.DepositTime()))
}

// MetaBuilder adds metadata fields to JSON
func metaBuilder() *json.NodeBuilder {
	height := std.ChainHeight()
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
