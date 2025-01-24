package launchpad

import (
	"errors"
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	en "gno.land/r/gnoswap/v1/emission"
	ppad "gno.land/p/gnoswap/v1/launchpad"
)

var (
	projects = make(map[string]ppad.Project) // projectId -> project

	// project tier should distribute project token if deposit ever happened
	// therefore we need to keep track of project tiers without deposit
	projectTiersWithoutDeposit = make(map[string]bool) // tierId -> true

	q128 = u256.Zero()
)

func init() {
	q128 = u256.MustFromDecimal(consts.Q128)
}

// ProjectCalculationResult middle result of project params calculation
type ProjectCalculationResult struct {
	Tier30Amount  uint64
	Tier90Amount  uint64
	Tier180Amount uint64
	StartHeight   uint64
}

// CreateProject creates a new project with specified tiers, conditions, and token deposit.
//
// This function initializes a project by validating the input, transferring the deposit amount,
// and creating the project's tiers. The project is stored globally and an event is emitted.
//
// Parameters:
// - name (string): The name of the project.
// - tokenPath (string): The token path for the deposit token.
// - recipient (std.Address): The address to receive the project's rewards.
// - depositAmount (uint64): The total amount of tokens to be deposited for the project.
// - conditionsToken (string): The token used for reward conditions.
// - conditionsAmount (string): The amount of the conditions token required.
// - tier30Ratio (uint64): The percentage of the deposit allocated to the 30-day tier.
// - tier90Ratio (uint64): The percentage of the deposit allocated to the 90-day tier.
// - tier180Ratio (uint64): The percentage of the deposit allocated to the 180-day tier.
// - startTime (uint64): The project's start time in Unix timestamp (seconds).
//
// Returns:
// - string: The unique ID of the created project.
func CreateProject(
	name string,
	tokenPath string,
	recipient std.Address,
	depositAmount uint64,
	conditionsToken string,
	conditionsAmount string,
	tier30Ratio uint64,
	tier90Ratio uint64,
	tier180Ratio uint64,
	startTime uint64,
) string {
	assertOnlyNotHalted()
	assertOnlyAdmin()

	input := ppad.NewProjectInput(name, tokenPath, recipient, depositAmount, conditionsToken, conditionsAmount, tier30Ratio, tier90Ratio, tier180Ratio, startTime)
	now := uint64(time.Now().Unix())
	conditions, err := input.CheckAll(now, common.IsRegistered)
	if err != nil {
		panic(err.Error())
	}

	en.MintAndDistributeGns()

	projectId := generateProjectId(input.TokenPath())
	if _, exists := projects[projectId]; exists {
		panic(addDetailToError(
			errDuplicateProject,
			ufmt.Sprintf("project(%s) already exists", projectId)))
	}

	// calcResult, err := calculateProjectParams(input, now)
	avgBlockTimeMs := uint64(gns.GetAvgBlockTimeInMs())
	calcResult, err := ppad.NewProjectCalculationResult(input, now, avgBlockTimeMs)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	startHeight := calcResult.StartHeight
	inputStartTime := input.StartTime()
	tier30, err := ppad.CreateTier(projectId, 30, calcResult.Tier30Amount, startHeight, inputStartTime, convertTimeToHeight(TIMESTAMP_3DAYS), avgBlockTimeMs, &rewardStates)
	if err != nil {
		panic(err.Error())
	}
	tier90, err := ppad.CreateTier(projectId, 90, calcResult.Tier90Amount, startHeight, inputStartTime, convertTimeToHeight(TIMESTAMP_7DAYS), avgBlockTimeMs, &rewardStates)
	if err != nil {
		panic(err.Error())
	}
	tier180, err := ppad.CreateTier(projectId, 180, calcResult.Tier180Amount, startHeight, inputStartTime, convertTimeToHeight(TIMESTAMP_14DAYS), avgBlockTimeMs, &rewardStates)
	if err != nil {
		panic(err.Error())
	}

	tierMap := map[uint64]ppad.Tier{
		TIER30:  tier30,
		TIER90:  tier90,
		TIER180: tier180,
	}

	tierRatioMap := map[uint64]uint64{
		TIER30:  input.Tier30Ratio(),
		TIER90:  input.Tier90Ratio(),
		TIER180: input.Tier180Ratio(),
	}

	projectCreated := ppad.NewTimeInfo(uint64(std.GetHeight()), now)
	projectStarted := ppad.NewTimeInfo(startHeight, inputStartTime)
	projectEnded := ppad.NewTimeInfo(tier180.Ended().Height(), tier180.Ended().Time())

	projectStats := ppad.NewProjectStats(0, 0, 0, 0, 0)

	refundInfo := ppad.NewRefundInfo(0, 0, 0)

	project := ppad.NewProject(
		projectId,
		name,
		tokenPath,
		depositAmount,
		recipient,
		conditions,
		tierMap,
		tierRatioMap,
		projectCreated,
		projectStarted,
		projectEnded,
		*projectStats,
		refundInfo,
	)

	projects[projectId] = *project

	// Transfer tokens
	tokenTeller := common.GetTokenTeller(tokenPath)
	tokenTeller.TransferFrom(
		getPrevAddr(),
		std.Address(GetOrigPkgAddr()),
		depositAmount,
	)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"CreateProject",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"name", name,
		"tokenPath", tokenPath,
		"recipient", recipient.String(),
		"depositAmount", formatUint(depositAmount),
		"conditionsToken", conditionsToken,
		"conditionsAmount", conditionsAmount,
		"tier30Ratio", formatUint(tier30Ratio),
		"tier90Ratio", formatUint(tier90Ratio),
		"tier180Ratio", formatUint(tier180Ratio),
		"startTime", formatUint(startTime),
		"startHeight", formatUint(startHeight),
		"projectId", projectId,
		"tier30Amount", formatUint(calcResult.Tier30Amount),
		"tier30EndHeight", formatUint(tier30.Ended().Height()),
		"tier90Amount", formatUint(calcResult.Tier90Amount),
		"tier90EndHeight", formatUint(tier90.Ended().Height()),
		"tier180Amount", formatUint(calcResult.Tier180Amount),
		"tier180EndHeight", formatUint(tier180.Ended().Height()),
	)

	return projectId
}

// TransferLeftFromProjectByAdmin transfers the remaining rewards of a project to a specified recipient.
//
// This function is called by an admin to transfer any unclaimed rewards from a project to a recipient address.
// It validates the project ID, checks the recipient conditions, calculates the remaining rewards, and performs the transfer.
//
// Parameters:
// - projectId (string): The unique identifier of the project.
// - recipient (std.Address): The recipient address to transfer the remaining rewards.
//
// Returns:
// - uint64: The amount of rewards transferred to the recipient.
func TransferLeftFromProjectByAdmin(projectId string, recipient std.Address) uint64 {
	if err := common.SatisfyCond(isUserCall()); err != nil {
		panic(addDetailToError(errNotUserCaller, err.Error()))
	}
	assertOnlyAdmin()
	assertOnlyNotHalted()

	project, err := getProject(projectId)
	if err != nil {
		panic(err.Error())
	}

	currentHeight := uint64(std.GetHeight())
	if err := validateTransferLeft(project, recipient, currentHeight); err != nil {
		panic(addDetailToError(
			errInvalidCondition, err.Error()))
	}

	en.MintAndDistributeGns()

	accumTotalReward := uint64(0)
	accumLeftReward := uint64(0)
	accumCollectedReward := uint64(0)
	tierMap := project.Tiers()
	for _, tier := range tierMap {
		if !tier.IsEnded(currentHeight) {
			panic(addDetailToError(
				errActiveProject, ufmt.Sprintf("tier(%d) is not ended", tier.ID())))
		}
		if tier.ActualParticipant() > 0 {
			panic(addDetailToError(
				errTierHasParticipants, ufmt.Sprintf("tier(%d) has (%d) participants", tier.ID(), tier.ActualParticipant())))
		}
		leftReward := tier.LeftReward()
		accumLeftReward += leftReward
		accumCollectedReward += tier.UserCollectedAmount()
		accumTotalReward += tier.TierAmount()
	}

	if accumTotalReward != accumCollectedReward+accumLeftReward {
		panic(addDetailToError(
			errInvalidRewardState, ufmt.Sprintf("accumTotalReward(%d) != accumCollectedReward(%d)+accumLeftReward(%d)", accumTotalReward, accumCollectedReward, accumLeftReward)))
	}

	projectLeftReward := project.LeftReward()
	refundInfo := ppad.NewRefundInfo(projectLeftReward, currentHeight, uint64(time.Now().Unix()))
	project.SetRefund(refundInfo)

	projects[projectId] = project

	if projectLeftReward > 0 {
		tokenTeller := common.GetTokenTeller(project.TokenPath())
		tokenTeller.Transfer(recipient, projectLeftReward)
	}

	std.Emit(
		"TransferLeftFromProjectByAdmin",
		"projectId", projectId,
		"recipient", recipient.String(),
		"tokenPath", project.TokenPath(),
		"leftReward", formatUint(projectLeftReward),
		"tier30Full", formatUint(project.Tiers()[30].TierAmount()),
		"tier30Left", formatUint(project.Tiers()[30].TierAmount()-project.Tiers()[30].CalculatedAmount()),
		"tier90Full", formatUint(project.Tiers()[90].TierAmount()),
		"tier90Left", formatUint(project.Tiers()[90].TierAmount()-project.Tiers()[90].CalculatedAmount()),
		"tier180Full", formatUint(project.Tiers()[180].TierAmount()),
		"tier180Left", formatUint(project.Tiers()[180].TierAmount()-project.Tiers()[180].CalculatedAmount()),
	)

	return projectLeftReward
}

// generateProjectId generates a unique project ID based on the given token path and the current block height.
//
// The generated ID combines the `tokenPath` and the current block height in the following format:
// "{tokenPath}:{height}"
//
// Parameters:
// - tokenPath (string): The path of the token associated with the project.
//
// Returns:
// - string: A unique project ID in the format "tokenPath:height".
//
// DEPRECATED: use `CreateId` instead
func generateProjectId(tokenPath string) string {
	// gno.land/r/gnoswap/gns:{height}
	// gno.land/r/gnoswap/gns:30
	return ufmt.Sprintf("%s:%d", tokenPath, std.GetHeight())
}

// generateTierId generates a unique tier ID based on the given project ID and the tier duration.
//
// The generated ID combines the `projectId` and the `duration` in the following format:
// "{projectId}:{duration}"
//
// Parameters:
// - projectId (string): The unique ID of the project associated with the tier.
// - duration (uint64): The duration of the tier (e.g., 30, 90, 180 days).
//
// Returns:
// - string: A unique tier ID in the format "projectId:duration".
//
// DEPRECATED: use `CreateId` instead
func generateTierId(projectId string, duration uint64) string {
	// gno.land/r/gnoswap/gns:{height}:{duration}
	// gno.land/r/gnoswap/gns:30:30(90,180)
	return ufmt.Sprintf("%s:%d", projectId, duration)
}


////////////////////////////////////////////


// createTier creates a new tier with the given parameters
func createTier(
	projectId string,
	duration uint64,
	amount uint64,
	startHeight uint64,
	startTime uint64,
	collectWaitDuration uint64) Tier {

	tierId := generateTierId(projectId, duration)

	tierStart := TimeInfo{
		height: startHeight,
		time:   startTime,
	}

	durationSecond := duration * TIMESTAMP_DAY
	endTime := startTime + durationSecond
	durationHeight := convertTimeToHeight(durationSecond)
	endHeight := startHeight + durationHeight
	tierEnded := TimeInfo{
		height: endHeight,
		time:   endTime,
	}

	rewardPerBlockX128 := calcRewardPerBlockX128(amount, durationHeight)

	// reward
	reward := NewReward(u256.Zero(), startHeight, endHeight)

	tier := Tier{
		id:                     tierId,
		collectWaitDuration:    collectWaitDuration,
		tierAmount:             amount,
		tierAmountPerBlockX128: rewardPerBlockX128,
		started:                tierStart,
		ended:                  tierEnded,
		totalDepositAmount:     0,
		actualDepositAmount:    0,
		totalParticipant:       0,
		actualParticipant:      0,
		userCollectedAmount:    0,
		calculatedAmount:       0,
		reward:                 *reward,
	}

	rewardState := ppad.NewRewardState(tier.tierAmountPerBlockX128, startHeight, endHeight)
	rewardStates.Set(projectId, strconv.FormatUint(duration, 10), rewardState)

	projectTiersWithoutDeposit[tierId] = true
	return tier
}

// validateTransferLeft validates the transfer of remaining tokens
func validateTransferLeft(project ppad.Project, recipient std.Address, height uint64) error {
	if !recipient.IsValid() {
		return errors.New(ufmt.Sprintf("invalid recipient address(%s)", recipient.String()))
	}

	if height < project.Ended().Height() {
		return errors.New(ufmt.Sprintf("project not ended yet(current:%d, endHeight: %d)",
			height, project.Ended().Height()))
	}

	if project.Refund().Height() != 0 {
		return errors.New(ufmt.Sprintf("project already refunded(height:%d)",
			project.Refund().Height()))
	}

	return nil
}

// calculateLeftReward calculates the remaining reward amount for each tier
func calculateLeftReward(project Project) uint64 {
	tier30 := project.tiers[30]
	tier90 := project.tiers[90]
	tier180 := project.tiers[180]

	left30 := tier30.tierAmount - tier30.calculatedAmount
	left90 := tier90.tierAmount - tier90.calculatedAmount
	left180 := tier180.tierAmount - tier180.calculatedAmount
	return left30 + left90 + left180
}

// getProject returns the project with the given project ID
func getProject(projectId string) (ppad.Project, error) {
	project, exists := projects[projectId]
	if !exists {
		return ppad.Project{}, errors.New(addDetailToError(
			errDataNotFound, ufmt.Sprintf("projectId(%s) not found", projectId)))
	}
	return project, nil
}
