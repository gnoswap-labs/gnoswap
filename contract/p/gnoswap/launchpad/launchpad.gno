package launchpad

import (
	"errors"
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

var (
	errEmptyTokenPath    = errors.New("token path cannot be empty")
	errInvalidAddress    = errors.New("invalid address")
	errZeroDepositAmount = errors.New("deposit amount cannot be 0")
)

// region: projectInput

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

// CheckAll checks all the project input fields.
// need to pass `IsRegistered` function as a callback parameter to check if the token is registered.
func (p *projectInput) CheckAll(now uint64, f func(string) error) (tokenConditionMap, error) {
	if err := p.checkName(); err != nil {
		return nil, err
	}
	if err := p.checkTokenPath(f); err != nil {
		return nil, err
	}
	if err := p.checkRecipient(); err != nil {
		return nil, err
	}
	if err := p.checkDepositAmount(); err != nil {
		return nil, err
	}
	if err := p.checkRatio(); err != nil {
		return nil, err
	}
	if err := p.checkStartTime(now); err != nil {
		return nil, err
	}

	conds, err := p.parseConditions(f)
	if err != nil {
		return nil, err
	}
	return conds, nil
}

// checkName checks if the project name is valid.
func (p *projectInput) checkName() error {
	if p.name == "" {
		return errors.New("project name cannot be empty")
	}
	if len(p.Name()) > 100 {
		return errors.New("project name is too long")
	}
	return nil
}

// checkRatio checks if the sum of the tier ratios equals 100.
func (p *projectInput) checkRatio() error {
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

// checkStartTime checks if the start time is in the future.
func (p *projectInput) checkStartTime(now uint64) error {
	if p.startTime <= now {
		return errors.New("start time must be greater than now")
	}
	return nil
}

func (p *projectInput) checkTokenPath(f func(string) error) error {
	path := p.TokenPath()
	if path == "" {
		return errEmptyTokenPath
	}
	if err := f(path); err != nil {
		return err
	}
	return nil
}

func (p *projectInput) checkRecipient() error {
	if !p.Recipient().IsValid() {
		return errInvalidAddress
	}
	return nil
}

func (p *projectInput) checkDepositAmount() error {
	if p.DepositAmount() == 0 {
		return errZeroDepositAmount
	}
	return nil
}

// ParseConditions parses the conditions from `ConditionsToken` and `ConditionsAmount`.
//
// Splits the token and amount strings using `*PAD*`, validates each token path, and converts
// the amounts to integers. Returns a map of token paths to their corresponding conditions.
func (p *projectInput) parseConditions(f func(string) error) (tokenConditionMap, error) {
	if p.ConditionsToken() == "" || p.ConditionsAmount() == "" {
		return nil, nil
	}

	return parseConditions(p.ConditionsToken(), p.ConditionsAmount(), f)
}

func parseConditions(condToken, condAmount string, f func(string) error) (tokenConditionMap, error) {
	tokens, amounts, err := trySplitConditions(condToken, condAmount)
	if err != nil {
		return nil, err
	}

	return buildTokenConditions(tokens, amounts, f)
}

func trySplitConditions(tokenStr, amountStr string) (tokens, amounts []string, err error) {
	if tokenStr == "" || amountStr == "" {
		return nil, nil, errors.New("conditionsToken or conditionsAmount cannot be empty")
	}

	tokens = strings.Split(tokenStr, PAD_SEP)
	amounts = strings.Split(amountStr, PAD_SEP)
	if len(tokens) != len(amounts) {
		return nil, nil, ufmt.Errorf("length of tokens(%d) and amounts(%d) are not same", len(tokens), len(amounts))
	}

	return tokens, amounts, nil
}

func buildTokenConditions(tokens, amounts []string, f func(string) error) (tokenConditionMap, error) {
	condition := make(tokenConditionMap)

	for i, tok := range tokens {
		if tok == "" {
			return nil, ufmt.Errorf("invalid token(%s)", tok)
		}
		if err := f(tok); err != nil {
			return nil, ufmt.Errorf("token(%s) not registered", tok)
		}
		if _, exists := condition[tok]; exists {
			return nil, ufmt.Errorf("duplicated condition token(%s)", tok)
		}

		amtv, err := strconv.ParseUint(amounts[i], 10, 64)
		if err != nil {
			return nil, ufmt.Errorf("invalid amount(%s)", amounts[i])
		}

		condition[tok] = Condition{
			tokenPath: tok,
			minAmount: amtv,
		}
	}
	return condition, nil
}

// region: ProjectCalculationResult

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
