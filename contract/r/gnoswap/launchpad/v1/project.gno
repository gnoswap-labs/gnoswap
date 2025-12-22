package v1

import (
	"errors"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"
)

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

func isProjectActive(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsActivated(currentTime)
}

func isProjectEnded(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsEnded(currentTime)
}

func checkProjectConditions(p *launchpad.Project, caller address, balanceOfFunc func(tokenPath string, caller address) int64) error {
	conditions := p.Conditions()
	if conditions == nil {
		return makeErrorWithDetails(errInvalidData, "conditions is nil")
	}

	for _, condition := range conditions {
		// xGNS(or GNS) may have a zero condition
		if !condition.IsAvailable() {
			continue
		}

		tokenPath := condition.TokenPath()
		balance := balanceOfFunc(tokenPath, caller)

		if err := condition.CheckBalanceCondition(tokenPath, balance); err != nil {
			return err
		}
	}

	return nil
}

func getProjectTier(p *launchpad.Project, duration int64) (*launchpad.ProjectTier, error) {
	tier, err := p.GetTier(duration)
	if err != nil {
		return nil, makeErrorWithDetails(errDataNotFound, err.Error())
	}

	return tier, nil
}

func getStandardTier(p *launchpad.Project) *launchpad.ProjectTier {
	projectTier, err := p.GetTier(projectTier180)
	if err != nil {
		panic(makeErrorWithDetails(errDataNotFound, err.Error()))
	}

	return projectTier
}

func validateRefundRemainingAmount(p *launchpad.Project, currentTime int64) error {
	if !isProjectEnded(p, currentTime) {
		return errors.New(
			ufmt.Sprintf("project not ended yet(current:%d, endTime: %d)", currentTime, getStandardTier(p).EndTime()),
		)
	}

	if getProjectStats(p).RemainingAmount == 0 {
		return errors.New(
			"project has no remaining amount",
		)
	}

	return nil
}

func addProjectTier(p *launchpad.Project, tierDuration int64, projectTier *launchpad.ProjectTier) {
	tiers := p.Tiers()
	tiers[tierDuration] = projectTier

	p.SetTiers(tiers)
}

func addProjectCondition(p *launchpad.Project, tokenPath string, condition *launchpad.ProjectCondition) {
	conditions := p.Conditions()
	conditions[tokenPath] = condition

	p.SetConditions(conditions)
}

func newProject(
	name string,
	tokenPath string,
	depositAmount int64,
	recipient address,
	createdHeight int64,
	createdAt int64,
) *launchpad.Project {
	return launchpad.NewProject(name, tokenPath, depositAmount, recipient, createdHeight, createdAt)
}
