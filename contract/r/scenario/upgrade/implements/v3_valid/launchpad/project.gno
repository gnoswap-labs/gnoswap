package v3

import (
	"errors"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"
)

func isProjectActive(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsActivated(currentTime)
}

func isProjectEnded(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsEnded(currentTime)
}

func getProjectRemainingAmount(p *launchpad.Project) int64 {
	remainingAmount := int64(0)

	for _, tier := range p.Tiers() {
		remainingAmount = safeAddInt64(remainingAmount, getCalculatedLeftReward(tier))
	}

	return remainingAmount
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

func getProjectTotalDepositCount(p *launchpad.Project) int64 {
	totalRecipient := int64(0)

	for _, tier := range p.Tiers() {
		totalRecipient = safeAddInt64(totalRecipient, tier.TotalDepositCount())
	}

	return totalRecipient
}

func getProjectTotalDepositAmount(p *launchpad.Project) int64 {
	totalDepositAmount := int64(0)

	for _, tier := range p.Tiers() {
		totalDepositAmount = safeAddInt64(totalDepositAmount, tier.TotalDepositAmount())
	}

	return totalDepositAmount
}

func getProjectCurrentDepositCount(p *launchpad.Project) int64 {
	totalDepositCount := int64(0)

	for _, tier := range p.Tiers() {
		totalDepositCount = safeAddInt64(totalDepositCount, getTierCurrentDepositCount(tier))
	}

	return totalDepositCount
}

func getProjectCurrentDepositAmount(p *launchpad.Project) int64 {
	totalDepositAmount := int64(0)

	for _, tier := range p.Tiers() {
		totalDepositAmount = safeAddInt64(totalDepositAmount, getTierCurrentDepositAmount(tier))
	}

	return totalDepositAmount
}

func getProjectTotalCollectedAmount(p *launchpad.Project) int64 {
	totalCollectedAmount := int64(0)

	for _, tier := range p.Tiers() {
		totalCollectedAmount = safeAddInt64(totalCollectedAmount, tier.TotalCollectedAmount())
	}

	return totalCollectedAmount
}

func getProjectConditions(p *launchpad.Project) map[string]*launchpad.ProjectCondition {
	return p.Conditions()
}

func getProjectTiers(p *launchpad.Project) map[int64]*launchpad.ProjectTier {
	return p.Tiers()
}

func getProjectTier(p *launchpad.Project, duration int64) (*launchpad.ProjectTier, error) {
	tier, exists := p.Tiers()[duration]
	if !exists {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("tier(%s) not found", duration))
	}

	return tier, nil
}

func getStandardTier(p *launchpad.Project) *launchpad.ProjectTier {
	projectTier, exists := p.Tiers()[projectTier180]
	if !exists {
		return nil
	}

	return projectTier
}

func validateRefundRemainingAmount(p *launchpad.Project, currentTime int64) error {
	if !isProjectEnded(p, currentTime) {
		return errors.New(
			ufmt.Sprintf("project not ended yet(current:%d, endTime: %d)", currentTime, getStandardTier(p).EndTime()),
		)
	}

	if getProjectRemainingAmount(p) == 0 {
		return errors.New(
			ufmt.Sprintf("project has no remaining amount"),
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
