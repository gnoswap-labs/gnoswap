package launchpad

import (
	"errors"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
)

// CreateProject creates a new launchpad project with tiered allocations.
//
// Parameters:
//   - name: project name
//   - tokenPath: reward token contract path
//   - recipient: project recipient address
//   - depositAmount: amount of tokens to deposit
//   - conditionTokens: comma-separated token paths for conditions
//   - conditionAmounts: comma-separated minimum amounts for conditions
//   - tier30Ratio: allocation ratio for 30-day tier
//   - tier90Ratio: allocation ratio for 90-day tier
//   - tier180Ratio: allocation ratio for 180-day tier
//   - startTime: unix timestamp for project start
//
// Returns project ID.
// Only callable by admin or governance.
func CreateProject(
	cur realm,
	name string,
	tokenPath string,
	recipient std.Address,
	depositAmount int64,
	conditionTokens string,
	conditionAmounts string,
	tier30Ratio int64,
	tier90Ratio int64,
	tier180Ratio int64,
	startTime int64,
) string {
	halt.AssertIsNotHaltedLaunchpad()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	launchpadAddr := std.CurrentRealm().Address()
	currentHeight := std.ChainHeight()
	currentTime := time.Now().Unix()

	params := &createProjectParams{
		name:                  name,
		tokenPath:             tokenPath,
		recipient:             recipient,
		depositAmount:         depositAmount,
		conditionTokens:       conditionTokens,
		conditionAmounts:      conditionAmounts,
		tier30Ratio:           tier30Ratio,
		tier90Ratio:           tier90Ratio,
		tier180Ratio:          tier180Ratio,
		startTime:             startTime,
		currentTime:           currentTime,
		currentHeight:         currentHeight,
		minimumStartDelayTime: projectMinimumStartDelayTime,
	}

	project, err := createProject(params)
	if err != nil {
		panic(err)
	}

	tokenBalance := common.BalanceOf(tokenPath, caller)
	if tokenBalance < depositAmount {
		panic(
			makeErrorWithDetails(
				errInsufficientBalance,
				ufmt.Sprintf("caller(%s) balance(%d) < depositAmount(%d)", launchpadAddr.String(), tokenBalance, depositAmount),
			),
		)
	}

	err = common.TransferFrom(
		cross,
		tokenPath,
		caller,
		launchpadAddr,
		depositAmount,
	)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"CreateProject",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"name", name,
		"tokenPath", tokenPath,
		"recipient", recipient.String(),
		"depositAmount", formatInt(depositAmount),
		"conditionsToken", params.conditionTokens,
		"conditionsAmount", params.conditionAmounts,
		"tier30Ratio", formatInt(params.tier30Ratio),
		"tier90Ratio", formatInt(params.tier90Ratio),
		"tier180Ratio", formatInt(params.tier180Ratio),
		"startTime", formatInt(params.startTime),
		"projectId", project.ID(),
		"tier30Amount", formatInt(project.tiers[projectTier30].TotalDistributeAmount()),
		"tier30EndTime", formatInt(project.tiers[projectTier30].EndTime()),
		"tier90Amount", formatInt(project.tiers[projectTier90].TotalDistributeAmount()),
		"tier90EndTime", formatInt(project.tiers[projectTier90].EndTime()),
		"tier180Amount", formatInt(project.tiers[projectTier180].TotalDistributeAmount()),
		"tier180EndTime", formatInt(project.tiers[projectTier180].EndTime()),
	)

	return project.ID()
}

// createProject creates a new project with the given parameters.
// This function validates the input parameters, creates the project structure,
// and sets up the project tiers and reward managers.
// Returns the created project and any error.
func createProject(params *createProjectParams) (*Project, error) {
	if err := params.validate(); err != nil {
		return nil, err
	}

	// create project
	project := NewProject(
		params.name,
		params.tokenPath,
		params.depositAmount,
		params.recipient,
		params.currentHeight,
		params.currentTime,
	)

	// check duplicate project
	if projects.Has(project.ID()) {
		return nil, makeErrorWithDetails(
			errDuplicateProject,
			ufmt.Sprintf("project(%s) already exists", project.ID()),
		)
	}

	projectConditions, err := NewProjectConditionsWithError(params.conditionTokens, params.conditionAmounts)
	if err != nil {
		return nil, err
	}

	for _, condition := range projectConditions {
		project.addProjectCondition(condition.tokenPath, condition)
	}

	projectTierRatios := map[int64]int64{
		projectTier30:  params.tier30Ratio,
		projectTier90:  params.tier90Ratio,
		projectTier180: params.tier180Ratio,
	}

	accumulatedTierDistributeAmount := int64(0)

	for _, duration := range projectTierDurations {
		rewardCollectableDuration := projectTierRewardCollectableDuration[duration]
		tierDurationTime := projectTierDurationTimes[duration]
		tierDistributeAmount := params.depositAmount * projectTierRatios[duration] / 100
		accumulatedTierDistributeAmount += tierDistributeAmount

		// if the last tier, distribute the remaining amount
		if duration == projectTier180 {
			remainTierDistributeAmount := params.depositAmount - accumulatedTierDistributeAmount
			tierDistributeAmount += remainTierDistributeAmount
		}

		projectTier := NewProjectTier(
			project.ID(),
			rewardCollectableDuration,
			tierDistributeAmount,
			params.startTime,
			params.startTime+tierDurationTime,
		)
		project.addProjectTier(duration, projectTier)

		projectTierRewardManagers.Set(projectTier.ID(), NewRewardManager(
			projectTier.TotalDistributeAmount(),
			projectTier.StartTime(),
			projectTier.EndTime(),
			params.startTime,
			params.startTime+tierDurationTime,
		))
	}

	projects.Set(project.ID(), project)

	return project, nil
}

// TransferLeftFromProjectByAdmin transfers the remaining rewards of a project to a specified recipient.
// Only admin or governance can call this function. Returns the amount of rewards transferred.
func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient std.Address) int64 {
	halt.AssertIsNotHaltedLaunchpad()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	currentHeight := std.ChainHeight()
	currentTime := time.Now().Unix()

	projectLeftReward, err := transferLeftFromProject(projectID, recipient, currentTime)
	if err != nil {
		panic(err)
	}

	project, err := getProject(projectID)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"TransferLeftFromProjectByAdmin",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"projectId", projectID,
		"recipient", recipient.String(),
		"tokenPath", project.tokenPath,
		"leftReward", formatInt(projectLeftReward),
		"tier30Full", formatInt(project.tiers[projectTier30].TotalDepositAmount()),
		"tier30Left", formatInt(project.tiers[projectTier30].calculateLeftReward()),
		"tier90Full", formatInt(project.tiers[projectTier90].TotalDepositAmount()),
		"tier90Left", formatInt(project.tiers[projectTier90].calculateLeftReward()),
		"tier180Full", formatInt(project.tiers[projectTier180].TotalDepositAmount()),
		"tier180Left", formatInt(project.tiers[projectTier180].calculateLeftReward()),
		"currentHeight", formatInt(currentHeight),
		"currentTime", formatInt(currentTime),
	)

	return projectLeftReward
}

// transferLeftFromProject transfers the remaining rewards of a project to a specified recipient.
// This function is called by an admin to transfer any unclaimed rewards from a project to a recipient address.
// It validates the project ID, checks the recipient conditions, calculates the remaining rewards, and performs the transfer.
// Returns the amount of rewards transferred to the recipient and any error.
func transferLeftFromProject(projectID string, recipient std.Address, currentTime int64) (int64, error) {
	project, err := getProject(projectID)
	if err != nil {
		return 0, err
	}

	if err := validateRefundProject(project, recipient, currentTime); err != nil {
		return 0, err
	}

	emission.MintAndDistributeGns(cross)

	accumTotalDistributeAmount := int64(0)
	accumLeftReward := int64(0)
	accumCollectedReward := int64(0)

	tierMap := project.getTiers()
	for _, tier := range tierMap {
		if !tier.isEnded(currentTime) {
			return 0, errors.New(ufmt.Sprintf("tier(%d) is not ended", tier.ID()))
		}

		if tier.CurrentDepositCount() > 0 {
			return 0, errors.New(ufmt.Sprintf("tier(%d) has (%d) participants", tier.ID(), tier.CurrentDepositCount()))
		}

		leftReward := tier.calculateLeftReward()
		accumLeftReward += leftReward
		accumCollectedReward += tier.TotalCollectedAmount()
		accumTotalDistributeAmount += tier.TotalDistributeAmount()
	}

	if accumTotalDistributeAmount != accumCollectedReward+accumLeftReward {
		return 0, errors.New(ufmt.Sprintf("accumTotalDistributeAmount(%d) != accumCollectedReward(%d)+accumLeftReward(%d)", accumTotalDistributeAmount, accumCollectedReward, accumLeftReward))
	}

	projectLeftReward := project.RemainingAmount()

	if projectLeftReward > 0 {
		if err := common.Transfer(cross, project.tokenPath, recipient, int64(projectLeftReward)); err != nil {
			return 0, makeErrorWithDetails(errTransferFailed, ufmt.Sprintf("token(%s), amount(%d)", project.tokenPath, projectLeftReward))
		}
	}

	return projectLeftReward, nil
}

// validateTransferLeft validates the transfer of remaining tokens
func validateRefundProject(project *Project, recipient std.Address, currentTime int64) error {
	if !recipient.IsValid() {
		return errors.New(ufmt.Sprintf("invalid recipient address(%s)", recipient.String()))
	}

	return project.validateRefundRemainingAmount(currentTime)
}

type createProjectParams struct {
	name                  string
	tokenPath             string
	recipient             std.Address
	depositAmount         int64
	conditionTokens       string
	conditionAmounts      string
	tier30Ratio           int64
	tier90Ratio           int64
	tier180Ratio          int64
	startTime             int64
	currentTime           int64
	currentHeight         int64
	minimumStartDelayTime int64
}

func (p *createProjectParams) validate() error {
	if err := p.validateName(); err != nil {
		return err
	}

	if err := p.validateTokenPath(); err != nil {
		return err
	}

	if err := p.validateRecipient(); err != nil {
		return err
	}

	if err := p.validateDepositAmount(); err != nil {
		return err
	}

	if err := p.validateRatio(); err != nil {
		return err
	}

	if err := p.validateStartTime(p.currentTime, p.minimumStartDelayTime); err != nil {
		return err
	}

	if err := p.validateConditions(); err != nil {
		return err
	}

	return nil
}

// validateName checks if the project name is valid.
func (p *createProjectParams) validateName() error {
	if p.name == "" {
		return makeErrorWithDetails(errInvalidInput, "project name cannot be empty")
	}

	if len(p.name) > 100 {
		return makeErrorWithDetails(errInvalidInput, "project name is too long")
	}

	return nil
}

// validateTokenPath validates the token path is not empty and is registered.
func (p *createProjectParams) validateTokenPath() error {
	if p.tokenPath == "" {
		return makeErrorWithDetails(errInvalidInput, "tokenPath cannot be empty")
	}

	if err := common.IsRegistered(p.tokenPath); err != nil && !isGovernanceToken(p.tokenPath) {
		return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("tokenPath(%s) not registered", p.tokenPath))
	}

	return nil
}

// validateRecipient checks if the recipient address is valid.
func (p *createProjectParams) validateRecipient() error {
	if !p.recipient.IsValid() {
		return makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf("recipient address(%s)", p.recipient.String()))
	}

	return nil
}

// validateDepositAmount ensures that the deposit amount is greater than zero.
func (p *createProjectParams) validateDepositAmount() error {
	if p.depositAmount == 0 {
		return makeErrorWithDetails(errInvalidInput, "deposit amount cannot be 0")
	}

	if p.depositAmount < 0 {
		return makeErrorWithDetails(errInvalidInput, "deposit amount cannot be negative")
	}

	return nil
}

// validateRatio checks if the sum of the tier ratios equals 100.
func (p *createProjectParams) validateRatio() error {
	sum := p.tier30Ratio + p.tier90Ratio + p.tier180Ratio
	if sum != 100 {
		return makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid ratio, sum of all tiers(30:%d, 90:%d, 180:%d) should be 100", p.tier30Ratio, p.tier90Ratio, p.tier180Ratio),
		)
	}

	return nil
}

// validateStartTime checks if the start time is available with minimum delay requirement.
func (p *createProjectParams) validateStartTime(now int64, minimumStartDelayTime int64) error {
	availableStartTime := now + minimumStartDelayTime

	if p.startTime < availableStartTime {
		return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("start time(%d) must be greater than now(%d)", p.startTime, availableStartTime))
	}

	return nil
}

func (p *createProjectParams) validateConditions() error {
	if p.conditionTokens == "" && p.conditionAmounts == "" {
		return nil
	}

	tokenPaths := strings.Split(p.conditionTokens, stringSplitterPad)
	minimumAmounts := strings.Split(p.conditionAmounts, stringSplitterPad)

	if len(tokenPaths) != len(minimumAmounts) {
		return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("conditionTokens and conditionAmounts are not matched"))
	}

	tokenPathMap := make(map[string]bool)

	for _, tokenPath := range tokenPaths {
		err := common.IsRegistered(tokenPath)
		if err != nil && !isGovernanceToken(tokenPath) {
			return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("tokenPath(%s) not registered", tokenPath))
		}

		if tokenPathMap[tokenPath] {
			return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("tokenPath(%s) is duplicated", tokenPath))
		}

		tokenPathMap[tokenPath] = true
	}

	for _, amountStr := range minimumAmounts {
		minimumAmount, err := strconv.ParseInt(amountStr, 10, 64)
		if err != nil {
			return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("invalid condition amount(%s)", amountStr))
		}

		if minimumAmount <= 0 {
			return makeErrorWithDetails(errInvalidInput, ufmt.Sprintf("condition amount(%s) is not available", amountStr))
		}
	}

	return nil
}

func isGovernanceToken(tokenPath string) bool {
	return tokenPath == GOV_XGNS_PATH
}
