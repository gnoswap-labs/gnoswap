package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"

	gs "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/launchpad"
)

/* Deposits */

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func (lp *launchpadV1) ApiGetDepositByDepositId(depositId string) string {
	deposits := lp.store.GetDeposits()
	deposit, exist := deposits.Get(depositId)
	if !exist {
		return ""
	}

	builder := metaBuilder()
	d, ok := deposit.(*launchpad.Deposit)
	if !ok {
		panic("failed to cast deposit to *launchpad.Deposit")
	}
	depositBuilder(builder, d)

	return marshal(builder.Node())
}

/* Project */

// ApiGetProjectAndTierStatisticsByProjectId retrieves project and tier statistics by project ID.
func (lp *launchpadV1) ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	projectBuilder(builder, project)

	for duration, tier := range project.Tiers() {
		tierBuilder(builder, ufmt.Sprintf("tier%d", duration), tier)
	}

	return marshal(builder.Node())
}

// ApiGetProjectStatisticsByProjectId retrieves project statistics by project ID.
func (lp *launchpadV1) ApiGetProjectStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	projectBuilder(builder, project)

	return marshal(builder.Node())
}

// ApiGetTierStatisticsByProjectId retrieves tier statistics by project ID.
func (lp *launchpadV1) ApiGetTierStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)

	for duration, tier := range project.Tiers() {
		tierBuilder(builder, ufmt.Sprintf("tier%d", duration), tier)
	}

	return marshal(builder.Node())
}

// ApiGetProjectStatisticsByProjectTierId retrieves project statistics by project tier ID.
func (lp *launchpadV1) ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	projectId, duration := parseProjectTierID(tierId)
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	tier, err := getProjectTier(project, duration)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	tierBuilder(builder, "tier", tier)

	return marshal(builder.Node())
}

// ApiGetProjectActiveOf retrieves project active status by project ID.
func (lp *launchpadV1) ApiGetProjectActiveOf(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}
	currentTime := time.Now().Unix()
	projectActiveResult := isProjectActive(project, currentTime)
	builder := (metaBuilder().
		WriteString("projectId", project.ID()).
		WriteString("isActive", formatBool(projectActiveResult)).
		WriteString("currentHeight", formatInt(runtime.ChainHeight()))).
		WriteString("startTime", formatInt(getStandardTier(project).StartTime()))
	return marshal(builder.Node())
}

/* Rewards */

// ApiGetProjectRecipientRewardByProjectId retrieves the claimable reward for a project recipient by project ID.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	projects := lp.store.GetProjects()
	project, exist := projects.Get(projectId)
	if !exist {
		return "0"
	}

	proj, ok := project.(*launchpad.Project)
	if !ok {
		panic(ufmt.Sprintf("failed to cast project to *launchpad.Project: %T", project))
	}
	return gs.GetClaimableRewardByAddress(proj.Recipient())
}

// ApiGetProjectRecipientRewardByAddress retrieves the claimable reward for a recipient by address.
func (lp *launchpadV1) ApiGetProjectRecipientRewardByAddress(address address) string {
	if !address.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(address)
}

// ProjectStats holds aggregated statistics for a project across all tiers.
// This struct is used to collect all stats in a single iteration over tiers.
type ProjectStats struct {
	TotalDepositCount    int64
	TotalDepositAmount   int64
	CurrentDepositCount  int64
	CurrentDepositAmount int64
	TotalCollectedAmount int64
	RemainingAmount      int64
}

// getProjectStats calculates all project statistics in a single iteration over tiers.
// This is more efficient than calling individual getter functions separately.
func getProjectStats(p *launchpad.Project) ProjectStats {
	var stats ProjectStats

	for _, tier := range p.Tiers() {
		stats.TotalDepositCount = safeAddInt64(stats.TotalDepositCount, tier.TotalDepositCount())
		stats.TotalDepositAmount = safeAddInt64(stats.TotalDepositAmount, tier.TotalDepositAmount())
		stats.CurrentDepositCount = safeAddInt64(stats.CurrentDepositCount, getTierCurrentDepositCount(tier))
		stats.CurrentDepositAmount = safeAddInt64(stats.CurrentDepositAmount, getTierCurrentDepositAmount(tier))
		stats.TotalCollectedAmount = safeAddInt64(stats.TotalCollectedAmount, tier.TotalCollectedAmount())
		stats.RemainingAmount = safeAddInt64(stats.RemainingAmount, getCalculatedLeftReward(tier))
	}

	return stats
}
