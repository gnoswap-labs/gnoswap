package launchpad

import (
	"errors"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/launchpad"
)

// isProjectActive reports whether a project's standard 180-day tier is active.
//
// Parameters:
//   - p: project whose standard tier is checked.
//   - currentTime: timestamp in Unix seconds used to evaluate the tier window.
//
// Returns:
//   - active: true when the standard tier satisfies startTime <= currentTime < endTime; false otherwise.
func isProjectActive(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsActivated(currentTime)
}

// isProjectEnded reports whether a project's standard 180-day tier has ended.
//
// Parameters:
//   - p: project whose standard tier is checked.
//   - currentTime: timestamp in Unix seconds used to compare with the tier end.
//
// Returns:
//   - ended: true when the standard tier's endTime is strictly less than currentTime; false otherwise.
func isProjectEnded(p *launchpad.Project, currentTime int64) bool {
	return getStandardTier(p).IsEnded(currentTime)
}

// getProjectRemainingAmount sums the calculated left reward across all project tiers.
//
// Parameters:
//   - p: project whose tier balances are aggregated.
//
// Returns:
//   - amount: sum of each tier's totalDistributeAmount minus totalCollectedAmount.
func getProjectRemainingAmount(p *launchpad.Project) int64 {
	remainingAmount := int64(0)

	for _, tier := range p.Tiers() {
		remainingAmount = gnsmath.SafeAddInt64(remainingAmount, getCalculatedLeftReward(tier))
	}

	return remainingAmount
}

// checkProjectConditions verifies the caller against every available project condition.
//
// Parameters:
//   - p: project whose token-balance conditions are checked.
//   - caller: address whose balances must satisfy the available conditions.
//   - balanceOfFunc: callback invoked with each condition token path and caller; it returns that caller's token balance.
//
// Returns:
//   - err: nil when all available conditions pass; non-nil when conditions are nil or any required balance is insufficient.
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

// getProjectTier retrieves the tier configured for a project duration.
//
// Parameters:
//   - p: project containing the tier map.
//   - duration: tier duration in days used as the lookup key.
//
// Returns:
//   - tier: matching project tier; nil when no tier is found.
//   - err: nil on success; non-nil when the project has no tier for duration.
func getProjectTier(p *launchpad.Project, duration int64) (*launchpad.ProjectTier, error) {
	tier, err := p.GetTier(duration)
	if err != nil {
		return nil, makeErrorWithDetails(errDataNotFound, err.Error())
	}

	return tier, nil
}

// getStandardTier retrieves the project's 180-day standard tier.
//
// Parameters:
//   - p: project containing the standard tier.
//
// It panics when the project's 180-day tier is not configured.
//
// Returns:
//   - tier: configured 180-day project tier.
func getStandardTier(p *launchpad.Project) *launchpad.ProjectTier {
	projectTier, err := p.GetTier(projectTier180)
	if err != nil {
		panic(makeErrorWithDetails(errDataNotFound, err.Error()))
	}

	return projectTier
}

// validateRefundRemainingAmount checks whether a project can transfer its remaining amount.
//
// Parameters:
//   - p: project whose end state and remaining reward balance are checked.
//   - currentTime: timestamp in Unix seconds used to determine whether the project has ended.
//
// Returns:
//   - err: nil when the project has ended and a nonzero amount remains; non-nil when it is still active or has no remaining amount.
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

// addProjectTier stores a tier under its duration in the project.
//
// Parameters:
//   - p: project whose tier map is updated.
//   - tierDuration: duration key in days for the tier.
//   - projectTier: tier value to associate with tierDuration.
func addProjectTier(p *launchpad.Project, tierDuration int64, projectTier *launchpad.ProjectTier) {
	p.SetTier(tierDuration, projectTier)
}

// addProjectCondition stores a condition under its token path in the project.
//
// Parameters:
//   - p: project whose condition map is updated.
//   - tokenPath: token contract path used as the condition key.
//   - condition: condition value to associate with tokenPath.
func addProjectCondition(p *launchpad.Project, tokenPath string, condition *launchpad.ProjectCondition) {
	p.SetCondition(tokenPath, condition)
}
