package launchpad

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/launchpad"
)

// Helper functions that access state through launchpadState

// getProject retrieves a project value from the persisted projects tree.
//
// Parameters:
//   - projectID: unique launchpad project identifier to look up.
//
// Returns:
//   - project: stored project pointer; nil when the ID is absent or the entry has an invalid type.
//   - err: nil for a valid project; non-nil when the ID is absent or the entry has an invalid type.
func (lp *launchpadV1) getProject(projectID string) (*launchpad.Project, error) {
	projects := lp.store.GetProjects()
	project := projects.Get(projectID)
	if project == nil {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	p, ok := project.(*launchpad.Project)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("project(%s) not found", projectID))
	}

	return p, nil
}

// getProjectTier retrieves a tier from a stored project.
//
// Parameters:
//   - projectID: unique launchpad project identifier containing the tier.
//   - tierDuration: tier duration in days used as the tier lookup key.
//
// Returns:
//   - tier: stored project tier; nil when the project or tier is absent.
//   - err: nil for a valid tier; non-nil when the project or tier cannot be found.
func (lp *launchpadV1) getProjectTier(projectID string, tierDuration int64) (*launchpad.ProjectTier, error) {
	project, err := lp.getProject(projectID)
	if err != nil {
		return nil, err
	}

	tier, err := project.GetTier(tierDuration)
	if err != nil {
		return nil, makeErrorWithDetails(errDataNotFound, err.Error())
	}

	return tier, nil
}

// getProjectTierRewardManager retrieves a reward manager from persisted state.
//
// Parameters:
//   - projectTierID: composite project-tier identifier used as the manager key.
//
// Returns:
//   - manager: stored reward manager; nil when the ID is absent or the entry has an invalid type.
//   - err: nil for a valid manager; non-nil when the ID is absent or the entry has an invalid type.
func (lp *launchpadV1) getProjectTierRewardManager(projectTierID string) (*launchpad.RewardManager, error) {
	managers := lp.store.GetProjectTierRewardManagers()
	rewardManager := managers.Get(projectTierID)
	if rewardManager == nil {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	manager, ok := rewardManager.(*launchpad.RewardManager)
	if !ok {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("reward manager(%s) not found", projectTierID))
	}

	return manager, nil
}

// getDepositValue retrieves a deposit payload from the persisted deposits tree.
//
// Parameters:
//   - depositId: unique deposit identifier used as the tree key.
//
// Returns:
//   - deposit: stored deposit value; zero-valued when the ID is absent or the entry has an invalid type.
//   - err: nil for a valid deposit; non-nil when the ID is absent or the entry has an invalid type.
func (lp *launchpadV1) getDepositValue(depositId string) (launchpad.Deposit, error) {
	deposits := lp.store.GetDeposits()
	value := deposits.Get(depositId)
	if value == nil {
		return launchpad.DefaultDeposit(), errors.New("deposit not found")
	}

	deposit, ok := value.(launchpad.Deposit)
	if !ok {
		return launchpad.DefaultDeposit(), errors.New("invalid deposit type")
	}
	return deposit, nil
}

// getDeposit retrieves and type-checks a deposit payload from persisted state.
//
// Parameters:
//   - depositID: unique deposit identifier used as the tree key.
//
// Returns:
//   - deposit: stored deposit value; zero-valued when the ID is absent or the entry has an invalid type.
//   - err: nil for a valid deposit; non-nil when the ID is absent or the entry has an invalid type.
func (lp *launchpadV1) getDeposit(depositID string) (launchpad.Deposit, error) {
	deposits := lp.store.GetDeposits()
	depositI := deposits.Get(depositID)
	if depositI == nil {
		return launchpad.DefaultDeposit(), makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositID))
	}

	deposit, ok := depositI.(launchpad.Deposit)
	if !ok {
		return launchpad.DefaultDeposit(), makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("deposit(%s) not found", depositID))
	}
	return deposit, nil
}

// mustGetDeposit retrieves a deposit and aborts execution if the lookup fails.
//
// Parameters:
//   - depositID: unique deposit identifier used as the tree key.
//
// Returns:
//   - deposit: valid stored deposit; the function panics instead of returning when lookup or type validation fails.
func (lp *launchpadV1) mustGetDeposit(depositID string) launchpad.Deposit {
	deposit, err := lp.getDeposit(depositID)
	if err != nil {
		panic(err)
	}

	return deposit
}

// nextDepositID increments and returns the next unique deposit ID.
// This is used when creating new deposits.
//
// Returns:
//   - depositID: next unique deposit identifier after incrementing the store counter.
func (lp *launchpadV1) nextDepositID() string {
	return lp.store.NextDepositID()
}
