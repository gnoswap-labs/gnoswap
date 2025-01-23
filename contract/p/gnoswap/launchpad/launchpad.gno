package launchpad

import (
	"errors"
	"std"

	"gno.land/p/demo/ufmt"
)

// ProjectInput defines the input parameters required to create a project.
//
// Fields:
// - Name (string): The name of the project.
// - TokenPath (string): The token path for the deposit token.
// - Recipient (std.Address): The recipient address for the project's rewards.
// - DepositAmount (uint64): The total deposit amount for the project.
// - ConditionsToken (string): A string containing token paths separated by `*PAD*`.
// - ConditionsAmount (string): A string containing corresponding amounts separated by `*PAD*`.
// - Tier30Ratio (uint64): The percentage of the deposit allocated to the 30-day tier.
// - Tier90Ratio (uint64): The percentage of the deposit allocated to the 90-day tier.
// - Tier180Ratio (uint64): The percentage of the deposit allocated to the 180-day tier.
// - StartTime (uint64): The start time of the project in Unix timestamp.
type projectInput struct {
	name             string
	tokenPath        string
	recipient        std.Address
	depositAmount    uint64
	conditionsToken  string // separated by PAD_SEP (`*PAD*`)
	conditionsAmount string // separated by PAD_SEP (`*PAD*`)
	tier30Ratio      uint64
	tier90Ratio      uint64
	tier180Ratio     uint64
	startTime        uint64
}

func (p *projectInput) Name() string             { return p.name }
func (p *projectInput) TokenPath() string        { return p.tokenPath }
func (p *projectInput) Recipient() std.Address   { return p.recipient }
func (p *projectInput) DepositAmount() uint64    { return p.depositAmount }
func (p *projectInput) ConditionsToken() string  { return p.conditionsToken }
func (p *projectInput) ConditionsAmount() string { return p.conditionsAmount }
func (p *projectInput) Tier30Ratio() uint64      { return p.tier30Ratio }
func (p *projectInput) Tier90Ratio() uint64      { return p.tier90Ratio }
func (p *projectInput) Tier180Ratio() uint64     { return p.tier180Ratio }
func (p *projectInput) StartTime() uint64        { return p.startTime }

// NewProjectInput creates and returns a new `ProjectInput` object.
//
// Parameters:
// - name (string): The name of the project.
// - tokenPath (string): The token path for the deposit token.
// - recipient (std.Address): The recipient address for the project's rewards.
// - depositAmount (uint64): The total deposit amount for the project.
// - conditionsToken (string): Token paths separated by `*PAD*`.
// - conditionsAmount (string): Corresponding amounts separated by `*PAD*`.
// - tier30Ratio (uint64): Allocation percentage for the 30-day tier.
// - tier90Ratio (uint64): Allocation percentage for the 90-day tier.
// - tier180Ratio (uint64): Allocation percentage for the 180-day tier.
// - startTime (uint64): The project's start time in Unix timestamp.
//
// Returns:
// - ProjectInput: The initialized `ProjectInput` object.
func NewProjectInput(
	name, tokenPath string,
	recipient std.Address,
	depositAmount uint64,
	conditionsToken string,
	conditionsAmount string,
	tier30Ratio uint64,
	tier90Ratio uint64,
	tier180Ratio uint64,
	startTime uint64,
) projectInput {
	return projectInput{
		name:             name,
		tokenPath:        tokenPath,
		recipient:        recipient,
		depositAmount:    depositAmount,
		conditionsToken:  conditionsToken,
		conditionsAmount: conditionsAmount,
		tier30Ratio:      tier30Ratio,
		tier90Ratio:      tier90Ratio,
		tier180Ratio:     tier180Ratio,
		startTime:        startTime,
	}
}

// CheckName checks if the project name is valid.
func (p *projectInput) CheckName() error {
	if p.name == "" {
		return errors.New("project name cannot be empty")
	}
	if len(p.Name()) > 100 {
		return errors.New("project name is too long")
	}
	return nil
}

// VerifyRatio checks if the sum of the tier ratios equals 100.
func (p *projectInput) VerifyRatio() error {
	if p.tierSum() != 100 {
		return ufmt.Errorf(
			"invalid ratio, sum of all tiers(30:%d, 90:%d, 180:%d) should be 100",
			p.tier30Ratio, p.tier90Ratio, p.tier180Ratio,
		)
	}
	return nil
}

func (p *projectInput) tierSum() uint64 {
	return p.Tier30Ratio() + p.Tier90Ratio() + p.Tier180Ratio()
}

// ValidateStartTime checks if the start time is in the future.
func (p *projectInput) ValidateStartTime(now uint64) error {
	if p.startTime <= now {
		return errors.New("start time must be greater than now")
	}
	return nil
}

func TierAmount(amount, ratio uint64) uint64 {
	return amount * ratio / 100
}

func calculateStartHeight(
	avgBlockTimeMs, now, start uint64,
) (uint64, error) {
	timeUntilStart := start - now
	blockDurationToStart, err := estimateTimeToHeight(avgBlockTimeMs, timeUntilStart)
	if err != nil {
		return 0, err
	}

	return uint64(std.GetHeight()) + blockDurationToStart, nil
}

// ProjectCalculationResult middle result of project params calculation
//
// TODO: Crwate getters
type ProjectCalculationResult struct {
	Tier30Amount  uint64
	Tier90Amount  uint64
	Tier180Amount uint64
	StartHeight   uint64
}

func NewProjectCalculationResult(
	input projectInput,
	now uint64,
	avgBlockTimeMs uint64,
) (*ProjectCalculationResult, error) {
	if input.StartTime() <= now {
		return nil, errors.New("start time must be greater than now")
	}

	startHeight, err := calculateStartHeight(avgBlockTimeMs, now, input.StartTime())
	if err != nil {
		return nil, err
	}

	amount := input.DepositAmount()

	return &ProjectCalculationResult{
		Tier30Amount:  TierAmount(amount, input.Tier30Ratio()),
		Tier90Amount:  TierAmount(amount, input.Tier90Ratio()),
		Tier180Amount: TierAmount(amount, input.Tier180Ratio()),
		StartHeight:   startHeight,
	}, nil
}

func CreateId(prefix, suffix string) string {
	return ufmt.Sprintf("%s:%s", prefix, suffix)
}
