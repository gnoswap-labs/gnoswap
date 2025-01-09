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

	// project tier should distrubte project token if deposit ever happend
	// therefore we need to keep track of project tiers without deposit
	projectTiersWithoutDeposit = make(map[string]bool) // tierId -> true
)

var (
	q96 = u256.Zero()
)

const (
	PAD_SEP = "*PAD*"
)

func init() {
	q96 = u256.MustFromDecimal(consts.Q96)
}

// ProjectInput represents the input parameters for creating a new project
type ProjectInput struct {
	Name             string
	TokenPath        string
	Recipient        std.Address
	DepositAmount    uint64
	ConditionsToken  string // spearated by PAD_SEP (`*PAD*`)
	ConditionsAmount string // spearated by PAD_SEP (`*PAD*`)
	Tier30Ratio      uint64
	Tier90Ratio      uint64
	Tier180Ratio     uint64
	StartTime        uint64
}

// validateProjectInput validates the input parameters for creating a new project
func validateProjectInput(input ProjectInput, now uint64) error {
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
func createTier(projectId string, duration uint64, amount uint64, startHeight uint64,
	startTime uint64, collectWaitDuration uint64) Tier {

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

	projectTiersWithoutDeposit[tierId] = true
	return tier
}

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
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

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
		panic(err)
	}

	if err := common.IsRegistered(tokenPath); err != nil {
		panic(err)
	}

	projectId := generateProjectId(tokenPath)
	if _, exists := projects[projectId]; exists {
		panic(ufmt.Sprintf("project(%s) already exists", projectId))
	}
	en.MintAndDistributeGns()

	// Transfer tokens
	tokenTeller := common.GetTokenTeller(tokenPath)
	tokenTeller.TransferFrom(
		caller,
		std.Address(consts.LAUNCHPAD_ADDR),
		depositAmount,
	)

	calcResult, err := calculateProjectParams(input, now)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	startHeight := calcResult.StartHeight

	tier30 := createTier(projectId, 30, calcResult.Tier30Amount, startHeight, startTime, covertToMillisecond(TIMESTAMP_3DAYS))
	tier90 := createTier(projectId, 90, calcResult.Tier90Amount, startHeight, startTime, covertToMillisecond(TIMESTAMP_7DAYS))
	tier180 := createTier(projectId, 180, calcResult.Tier180Amount, startHeight, startTime, covertToMillisecond(TIMESTAMP_14DAYS))

	conditions := makeConditions(conditionsToken, conditionsAmount)

	project := Project{
		id:            projectId,
		name:          name,
		tokenPath:     tokenPath,
		depositAmount: depositAmount,
		recipient:     recipient,
		conditions:    conditions,
		tiers: map[uint64]Tier{
			30:  tier30,
			90:  tier90,
			180: tier180,
		},
		tiersRatios: map[uint64]uint64{
			30:  tier30Ratio,
			90:  tier90Ratio,
			180: tier180Ratio,
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

// middle result of project params calculation
type ProjectCalculationResult struct {
	Tier30Amount  uint64
	Tier90Amount  uint64
	Tier180Amount uint64
	StartHeight   uint64
}

func calculateProjectParams(input ProjectInput, now uint64) (*ProjectCalculationResult, error) {
	tier30Amount := input.DepositAmount * input.Tier30Ratio / 100
	tier90Amount := input.DepositAmount * input.Tier90Ratio / 100
	tier180Amount := input.DepositAmount * input.Tier180Ratio / 100

	if input.StartTime < now {
		return nil, ufmt.Errorf("startTime(%d) must be greater than now(%d)", input.StartTime, now)
	}

	// calculate when the block starts
	timeUntilStart := input.StartTime - now

	avgBlockTimeMs := uint64(gns.GetAvgBlockTimeInMs())
	if avgBlockTimeMs == 0 {
		return nil, ufmt.Errorf("average block time not available")
	}

	blockDuration := timeUntilStart * 1000 / avgBlockTimeMs
	height := uint64(std.GetHeight())
	startHeight := height + blockDuration

	return &ProjectCalculationResult{
		Tier30Amount:  tier30Amount,
		Tier90Amount:  tier90Amount,
		Tier180Amount: tier180Amount,
		StartHeight:   startHeight,
	}, nil
}

func covertToMillisecond(timestamp uint64) uint64 {
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

func TransferLeftFromProjectByAdmin(projectId string, recipient std.Address) uint64 {
	if err := common.SatisfyCond(isUserCall()); err != nil {
		panic(addDetailToError(errAlreadyRefunded, err.Error()))
	}

	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(addDetailToError(errInvalidAddress, err.Error()))
	}

	project, exists := projects[projectId]
	if !exists {
		panic(addDetailToError(errDataNotFound, ufmt.Sprintf("projectId(%s) not found", projectId)))
	}

	height := uint64(std.GetHeight())
	if err := validateTransferLeft(project, recipient, height); err != nil {
		panic(err)
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	project = projects[projectId] // get updated project

	leftReward := rewardStates.DeleteProject(projectId)

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
		panic(ufmt.Sprintf("invalid conditions(numTokens(%d) != numAmounts(%d))",
			len(tokens), len(amounts)))
	}

	conditions := make(map[string]Condition)
	for i, token := range tokens {
		minAmount, err := strconv.ParseUint(amounts[i], 10, 64)
		if err != nil {
			panic(err)
		}

		conditions[token] = Condition{
			tokenPath: token,
			minAmount: minAmount,
		}
	}
	return conditions
}

func generateProjectId(tokenPath string) string {
	// gno.land/r/gnoswap/gns:{height}
	// gno.land/r/gnoswap/gns:30
	return ufmt.Sprintf("%s:%d", tokenPath, std.GetHeight())
}

func generateTierId(projectId string, duration uint64) string {
	// gno.land/r/gnoswap/gns:{height}:{duration}
	// gno.land/r/gnoswap/gns:30:30(90,180)
	return ufmt.Sprintf("%s:%d", projectId, duration)
}
