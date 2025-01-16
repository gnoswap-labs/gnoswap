package launchpad

import (
	"errors"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
)

var (
	projects = make(map[string]Project) // projectId -> project

	// project tier should distribute project token if deposit ever happened
	// therefore we need to keep track of project tiers without deposit
	projectTiersWithoutDeposit = make(map[string]bool) // tierId -> true
)

var (
	q128 = u256.Zero()
)

const (
	PAD_SEP = "*PAD*"
)

func init() {
	q128 = u256.MustFromDecimal(consts.Q128)
}

// ProjectInput represents the input parameters for creating a new project
type ProjectInput struct {
	Name             string
	TokenPath        string
	Recipient        std.Address
	DepositAmount    uint64
	ConditionsToken  string // separated by PAD_SEP (`*PAD*`)
	ConditionsAmount string // separated by PAD_SEP (`*PAD*`)
	Tier30Ratio      uint64
	Tier90Ratio      uint64
	Tier180Ratio     uint64
	StartTime        uint64
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
	assertOnlyValidAddress(recipient)

	input := ProjectInput{
		Name:             name,
		TokenPath:        tokenPath,
		Recipient:        recipient,
		DepositAmount:    depositAmount,
		ConditionsToken:  conditionsToken,
		ConditionsAmount: conditionsAmount,
		Tier30Ratio:      tier30Ratio,
		Tier90Ratio:      tier90Ratio,
		Tier180Ratio:     tier180Ratio,
		StartTime:        startTime,
	}

	now := uint64(time.Now().Unix())
	if err := validateProjectInput(input, now); err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	if err := common.IsRegistered(tokenPath); err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	projectId := generateProjectId(tokenPath)
	if _, exists := projects[projectId]; exists {
		panic(addDetailToError(
			errDuplicateProject,
			ufmt.Sprintf("project(%s) already exists", projectId)))
	}
	en.MintAndDistributeGns()

	// Transfer tokens
	tokenTeller := common.GetTokenTeller(tokenPath)
	tokenTeller.TransferFrom(
		getPrevAddr(),
		std.Address(GetOrigPkgAddr()),
		depositAmount,
	)

	calcResult, err := calculateProjectParams(input, now)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	startHeight := calcResult.StartHeight

	tier30 := createTier(projectId, 30, calcResult.Tier30Amount, startHeight, startTime, covertTimeToHeight(TIMESTAMP_3DAYS))
	tier90 := createTier(projectId, 90, calcResult.Tier90Amount, startHeight, startTime, covertTimeToHeight(TIMESTAMP_7DAYS))
	tier180 := createTier(projectId, 180, calcResult.Tier180Amount, startHeight, startTime, covertTimeToHeight(TIMESTAMP_14DAYS))

	conditions := makeConditions(conditionsToken, conditionsAmount)

	project := Project{
		id:            projectId,
		name:          name,
		tokenPath:     tokenPath,
		depositAmount: depositAmount,
		recipient:     recipient,
		conditions:    conditions,
		tiers: map[uint64]Tier{
			TIER30:  tier30,
			TIER90:  tier90,
			TIER180: tier180,
		},
		tiersRatios: map[uint64]uint64{
			TIER30:  tier30Ratio,
			TIER90:  tier90Ratio,
			TIER180: tier180Ratio,
		},
		created: TimeInfo{
			height: uint64(std.GetHeight()),
			time:   now,
		},
		started: TimeInfo{
			height: startHeight,
			time:   startTime,
		},
		ended: TimeInfo{
			height: tier180.ended.height,
			time:   tier180.ended.time,
		},
	}

	projects[projectId] = project

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
		"tier30EndHeight", formatUint(tier30.ended.height),
		"tier90Amount", formatUint(calcResult.Tier90Amount),
		"tier90EndHeight", formatUint(tier90.ended.height),
		"tier180Amount", formatUint(calcResult.Tier180Amount),
		"tier180EndHeight", formatUint(tier180.ended.height),
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

	project, exists := projects[projectId]
	if !exists {
		panic(addDetailToError(errDataNotFound, ufmt.Sprintf("projectId(%s) not found", projectId)))
	}

	height := uint64(std.GetHeight())
	if err := validateTransferLeft(project, recipient, height); err != nil {
		panic(addDetailToError(
			errInvalidCondition, err.Error()))
	}

	en.MintAndDistributeGns()

	project = projects[projectId] // get updated project

	leftReward := rewardStates.DeleteProject(projectId)

	// TODO:
	// compare with (totalAmount - distributedAmount)

	if leftReward > 0 {
		tokenTeller := common.GetTokenTeller(project.tokenPath)
		tokenTeller.Transfer(recipient, leftReward)
	}

	std.Emit(
		"TransferLeftFromProjectByAdmin",
		"projectId", projectId,
		"recipient", recipient.String(),
		"tokenPath", project.tokenPath,
		"leftReward", strconv.FormatUint(leftReward, 10),
		"tier30Full", strconv.FormatUint(project.tiers[30].tierAmount, 10),
		"tier30Left", strconv.FormatUint(project.tiers[30].tierAmount-project.tiers[30].calculatedAmount, 10),
		"tier90Full", strconv.FormatUint(project.tiers[90].tierAmount, 10),
		"tier90Left", strconv.FormatUint(project.tiers[90].tierAmount-project.tiers[90].calculatedAmount, 10),
		"tier180Full", strconv.FormatUint(project.tiers[180].tierAmount, 10),
		"tier180Left", strconv.FormatUint(project.tiers[180].tierAmount-project.tiers[180].calculatedAmount, 10),
	)

	project.refund = RefundInfo{
		amount: leftReward,
		height: height,
		time:   uint64(time.Now().Unix()),
	}
	projects[projectId] = project

	return leftReward
}

// makeConditions creates conditions map from token and amount strings
func makeConditions(conditionsToken string, conditionsAmount string) map[string]Condition {
	if conditionsToken == "" || conditionsAmount == "" {
		return nil
	}

	tokens := strings.Split(conditionsToken, PAD_SEP)
	amounts := strings.Split(conditionsAmount, PAD_SEP)
	if len(tokens) != len(amounts) {
		panic(addDetailToError(
			errInvalidLength,
			ufmt.Sprintf("invalid conditions(numTokens(%d) != numAmounts(%d))", len(tokens), len(amounts))))
	}

	conditions := make(map[string]Condition)
	for i, token := range tokens {
		minAmount, err := strconv.ParseUint(amounts[i], 10, 64)
		if err != nil {
			panic(addDetailToError(
				errConvertFail, err.Error()))
		}

		conditions[token] = Condition{
			tokenPath: token,
			minAmount: minAmount,
		}
	}
	return conditions
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
func generateTierId(projectId string, duration uint64) string {
	// gno.land/r/gnoswap/gns:{height}:{duration}
	// gno.land/r/gnoswap/gns:30:30(90,180)
	return ufmt.Sprintf("%s:%d", projectId, duration)
}

// validateProjectInput validates the input parameters for creating a new project
func validateProjectInput(input ProjectInput, now uint64) error {
	if input.Name == "" {
		return errors.New("invalid project name")
	}

	if input.Tier30Ratio+input.Tier90Ratio+input.Tier180Ratio != 100 {
		return errors.New(ufmt.Sprintf("invalid ratio, sum of all tiers(30:%d, 90:%d, 180:%d) should be 100",
			input.Tier30Ratio, input.Tier90Ratio, input.Tier180Ratio))
	}

	if input.StartTime <= now {
		return errors.New(ufmt.Sprintf("invalid start time(%d), cannot start project in past(now:%d)",
			input.StartTime, now))
	}

	if input.DepositAmount == 0 {
		return errors.New("cannot deposit 0")
	}

	if !input.Recipient.IsValid() {
		return errors.New(ufmt.Sprintf("invalid recipient address(%s)", input.Recipient.String()))
	}

	return nil
}

// createTier creates a new tier with the given parameters
func createTier(
	projectId string,
	duration uint64,
	amount uint64,
	startHeight uint64,
	startTime uint64,
	collectWaitDuration uint64) Tier {

	tierId := generateTierId(projectId, duration)
	endTime := startTime + (duration * TIMESTAMP_DAY)
	endHeight := startHeight + (duration * TIMESTAMP_DAY * 1000 / uint64(gns.GetAvgBlockTimeInMs()))

	tier := Tier{
		id:                  tierId,
		collectWaitDuration: collectWaitDuration,
		tierAmount:          amount,
		ended: TimeInfo{
			height: endHeight,
			time:   endTime,
		},
	}

	// Calculate reward per block for the tier
	tier.tierAmountPerBlockX128 = calcProjectTiersRewardPerBlockX128(tier)

	// Initialize reward state for this tier
	rewardState := NewRewardState(tier.tierAmountPerBlockX128, startHeight, endHeight)
	rewardStates.Set(projectId, strconv.FormatUint(duration, 10), rewardState)

	projectTiersWithoutDeposit[tierId] = true
	return tier
}

// calculateProjectParams calculates project-related parameters based on the input and current time.
//
// This function computes the amounts for three tiers (30, 90, and 180), as well as the block height
// when the project starts based on the provided start time.
//
// Parameters:
// - input (ProjectInput): The input parameters for the project.
//   - DepositAmount (uint64): The total deposit amount.
//   - Tier30Ratio (uint64): The percentage of the deposit allocated to the 30-day tier.
//   - Tier90Ratio (uint64): The percentage of the deposit allocated to the 90-day tier.
//   - Tier180Ratio (uint64): The percentage of the deposit allocated to the 180-day tier.
//   - StartTime (uint64): The project start time in Unix timestamp (seconds).
//
// - now (uint64): The current time in Unix timestamp (seconds).
//
// Returns:
// - *ProjectCalculationResult: A pointer to the calculated results, including tier amounts and start height.
// - error: Returns an error if the start time is earlier than the current time or if the average block time is unavailable.
func calculateProjectParams(input ProjectInput, now uint64) (*ProjectCalculationResult, error) {
	tier30Amount := input.DepositAmount * input.Tier30Ratio / 100
	tier90Amount := input.DepositAmount * input.Tier90Ratio / 100
	tier180Amount := input.DepositAmount * input.Tier180Ratio / 100

	if input.StartTime < now {
		return nil, ufmt.Errorf("startTime(%d) must be greater than now(%d)", input.StartTime, now)
	}

	avgBlockTimeMs := uint64(gns.GetAvgBlockTimeInMs())
	if avgBlockTimeMs == 0 {
		return nil, ufmt.Errorf("average block time not available")
	}

	// calculate when the block starts
	timeUntilStart := input.StartTime - now

	blockDuration := timeUntilStart * 1000 / avgBlockTimeMs
	currentHeight := uint64(std.GetHeight())
	startHeight := currentHeight + blockDuration

	return &ProjectCalculationResult{
		Tier30Amount:  tier30Amount,
		Tier90Amount:  tier90Amount,
		Tier180Amount: tier180Amount,
		StartHeight:   startHeight,
	}, nil
}

// covertTimeToHeight converts the given timestamp to block height based on the average block time.
func covertTimeToHeight(timestamp uint64) uint64 {
	return timestamp * 1000 / uint64(gns.GetAvgBlockTimeInMs())
}

// validateTransferLeft validates the transfer of remaining tokens
func validateTransferLeft(project Project, recipient std.Address, height uint64) error {
	if !recipient.IsValid() {
		return errors.New(ufmt.Sprintf("invalid recipient address(%s)", recipient.String()))
	}

	if height < project.ended.height {
		return errors.New(ufmt.Sprintf("project not ended yet(current:%d, endHeight: %d)",
			height, project.ended.height))
	}

	if project.refund.height != 0 {
		return errors.New(ufmt.Sprintf("project already refunded(height:%d)",
			project.refund.height))
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
