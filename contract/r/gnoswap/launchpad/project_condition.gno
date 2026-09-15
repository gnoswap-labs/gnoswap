package launchpad

import (
	"strconv"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
)

const stringSplitterPad = "*PAD*"

// ProjectCondition represents a condition for a project.
//
// This struct contains the necessary data and methods to manage and distribute
// rewards for a specific project.
//
// Fields:
// - tokenPath (string): The path of the token associated with the project.
// - minimumAmount (int64): The minimum amount of the token required for the project.
type ProjectCondition struct {
	tokenPath     string
	minimumAmount int64
}

// TokenPath returns the token contract path required by this condition.
//
// Returns:
//   - tokenPath: configured condition token path; an empty string means no token is configured.
func (p *ProjectCondition) TokenPath() string {
	return p.tokenPath
}

// MinimumAmount returns the minimum balance amount required by this condition.
//
// Returns:
//   - minimumAmount: minimum amount in the token's base units; values at or below zero make the condition unavailable.
func (p *ProjectCondition) MinimumAmount() int64 {
	return p.minimumAmount
}

// IsAvailable reports whether this condition has a non-empty token path and a positive minimum amount.
//
// Returns:
//   - available: true when both the token path and minimum amount are valid; false otherwise.
func (p *ProjectCondition) IsAvailable() bool {
	return p.tokenPath != "" && p.minimumAmount > 0
}

// CheckBalanceCondition validates an input token balance against this condition.
//
// Parameters:
//   - inputTokenPath: token path whose balance is being checked; it must equal the condition token path.
//   - inputAmount: input token balance in base units; it must be at least the configured minimum.
//
// Returns:
//   - err: nil when the token path and amount satisfy the condition; non-nil describing a mismatch otherwise.
func (p *ProjectCondition) CheckBalanceCondition(inputTokenPath string, inputAmount int64) error {
	if p.tokenPath != inputTokenPath {
		return ufmt.Errorf("token path(%s) is not matched", inputTokenPath)
	}

	if inputAmount < p.minimumAmount {
		return ufmt.Errorf("input amount(%d) is less than minimum amount(%d)", inputAmount, p.minimumAmount)
	}

	return nil
}

// Clone returns an independent copy of this project condition.
//
// Returns:
//   - condition: copied token path and minimum amount in a new ProjectCondition value.
func (p ProjectCondition) Clone() *ProjectCondition {
	return &ProjectCondition{
		tokenPath:     p.tokenPath,
		minimumAmount: p.minimumAmount,
	}
}

// NewProjectCondition creates a project condition for a token path and minimum amount.
//
// Parameters:
//   - tokenPath: token contract path whose balance is required.
//   - minimumAmount: minimum balance in the token's base units.
//
// Returns:
//   - condition: newly allocated project condition containing the supplied values.
func NewProjectCondition(tokenPath string, minimumAmount int64) *ProjectCondition {
	return &ProjectCondition{
		tokenPath:     tokenPath,
		minimumAmount: minimumAmount,
	}
}

// NewProjectConditionsWithError parses parallel *PAD*-separated token paths and minimum amounts.
//
// Parameters:
//   - conditionTokens: *PAD*-separated token contract paths, in condition order.
//   - conditionAmounts: *PAD*-separated decimal int64 minimum amounts paired by index with conditionTokens; entries beyond the token list are not consumed.
//
// Returns:
//   - conditions: parsed available conditions in the same order as their token paths; empty when both inputs are empty.
//   - err: nil on successful parsing; non-nil when a token lacks a matching amount, an amount is not a valid int64, or a condition is unavailable.
func NewProjectConditionsWithError(conditionTokens string, conditionAmounts string) ([]*ProjectCondition, error) {
	if conditionTokens == "" && conditionAmounts == "" {
		return []*ProjectCondition{}, nil
	}

	conditions := []*ProjectCondition{}

	tokenPaths := strings.Split(conditionTokens, stringSplitterPad)
	minimumAmounts := strings.Split(conditionAmounts, stringSplitterPad)

	for index, tokenPath := range tokenPaths {
		if index >= len(minimumAmounts) {
			return nil, ufmt.Errorf("condition amount(%s) is not matched with condition token(%s)", conditionAmounts, conditionTokens)
		}

		minimumAmount, err := strconv.ParseInt(minimumAmounts[index], 10, 64)
		if err != nil {
			return nil, ufmt.Errorf("condition amount(%s) is not a valid integer", minimumAmounts[index])
		}

		condition := NewProjectCondition(tokenPath, minimumAmount)
		if !condition.IsAvailable() {
			return nil, ufmt.Errorf("condition(%s) is not available", condition.TokenPath())
		}

		conditions = append(conditions, condition)
	}

	return conditions, nil
}
