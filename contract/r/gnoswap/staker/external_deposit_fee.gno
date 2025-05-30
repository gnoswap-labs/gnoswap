package staker

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
)

var depositGnsAmount = uint64(1_000_000_000)    // 1_000 GNS
var minimumRewardAmount = uint64(1_000_000_000) // Default 1000 (ugnot equivalent for GNS)

// tokenSpecificMinimumRewards stores minimum reward amounts for specific tokens.
// Key: tokenPath (string), Value: minimumAmount (uint64)
var tokenSpecificMinimumRewards = avl.NewTree()

// GetDepositGnsAmount returns the current deposit amount in GNS.
//
// Returns:
// - uint64: The deposit amount in GNS.
func GetDepositGnsAmount() uint64 {
	return depositGnsAmount
}

// GetMinimumRewardAmount returns the default minimum reward amount required for external incentives.
// This value is used if no specific minimum is set for a given token.
//
// Returns:
// - uint64: The default minimum reward amount.
func GetMinimumRewardAmount() uint64 {
	return minimumRewardAmount
}

// GetTokenMinimumRewardAmount returns the specific minimum reward amount for a given token path.
// It first checks the token-specific map and falls back to the default if not found.
//
// Parameters:
// - tokenPath (string): The path of the token to check.
//
// Returns:
// - uint64: The applicable minimum reward amount for the token.
func GetMinimumRewardAmountForToken(tokenPath string) uint64 {
	amountI, found := tokenSpecificMinimumRewards.Get(tokenPath)
	if found {
		return amountI.(uint64)
	}
	// Fallback to default if not found
	return GetMinimumRewardAmount()
}

// GetSpecificTokenMinimumRewardAmount returns the explicitly set minimum reward amount for a token,
// and a boolean indicating if it was found in the specific map.
// This is useful for querying the set value without the fallback.
//
// Parameters:
// - tokenPath (string): The path of the token to query.
//
// Returns:
// - uint64: The specific minimum reward amount set for the token.
// - bool: True if a specific minimum was found, false otherwise.
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (uint64, bool) {
	amountI, found := tokenSpecificMinimumRewards.Get(tokenPath)
	if found {
		return amountI.(uint64), true
	}
	return 0, false
}

// SetDepositGnsAmountByAdmin allows an admin to set the deposit amount in GNS.
//
// This function validates the caller as an admin using `common.AdminOnly`.
// If successful, it updates the deposit amount and emits an event with details
// of the change.
//
// Parameters:
// - amount (uint64): The new deposit amount in GNS.
//
// Panics:
// - If the caller is not an admin.
func SetDepositGnsAmountByAdmin(amount uint64) {
	caller := getPrevAddr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}

	prevDepositGnsAmount := getDepositGnsAmount()
	setDepositGnsAmount(amount)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetDepositGnsAmountByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevAmount", formatUint(prevDepositGnsAmount),
		"newAmount", formatUint(amount),
	)
}

// SetMinimumRewardAmountByAdmin allows an admin to set the *default* minimum reward amount.
//
// Parameters:
// - amount (uint64): The new minimum reward amount.
//
// Panics:
// - If the caller is not an admin.
func SetMinimumRewardAmountByAdmin(amount uint64) {
	caller := getPrevAddr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err.Error())
	}

	prevMinimumRewardAmount := getMinimumRewardAmount()
	setMinimumRewardAmount(amount)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetMinimumRewardAmountByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevAmount", formatUint(prevMinimumRewardAmount),
		"newAmount", formatUint(amount),
	)
}

// SetDepositGnsAmount modifies the deposit gns amount
// Only governance contract can execute this function via proposal
// ref: https://docs.gnoswap.io/contracts/staker/external_deposit_fee.gno
func SetDepositGnsAmount(amount uint64) {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}

	prevDepositGnsAmount := getDepositGnsAmount()
	setDepositGnsAmount(amount)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetDepositGnsAmount",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevAmount", formatUint(prevDepositGnsAmount),
		"newAmount", formatUint(amount),
	)
}

// SetMinimumRewardAmount modifies the *default* minimum reward amount.
// Only governance contract can execute this function via proposal.
func SetMinimumRewardAmount(amount uint64) {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}

	prevMinimumRewardAmount := getMinimumRewardAmount()
	setMinimumRewardAmount(amount)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"SetMinimumRewardAmount",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"prevAmount", formatUint(prevMinimumRewardAmount),
		"newAmount", formatUint(amount),
	)
}

// SetTokenMinimumRewardAmount modifies the minimum reward amount for a specific token.
// Only governance contract can execute this function via proposal.
// It expects the parameter `paramsStr` to be formatted as "tokenPath:amount".
//
// Parameters:
//   - paramsStr (string): A string containing the token path and minimum amount, separated by a colon.
//     Example: "gno.land/r/demo/wugnot:1500000000"
func SetTokenMinimumRewardAmount(paramsStr string) {
	caller := getPrevAddr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err.Error())
	}

	// Parse the paramsStr
	parts := strings.SplitN(paramsStr, ":", 2)
	if len(parts) != 2 {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid format for SetTokenMinimumRewardAmount params: expected 'tokenPath:amount', got '%s'", paramsStr),
		))
	}
	tokenPath := parts[0]
	amountStr := parts[1]
	amount, err := strconv.ParseUint(amountStr, 10, 64)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amount format in params '%s': %v", paramsStr, err),
		))
	}

	prevAmount, found := GetSpecificTokenMinimumRewardAmount(tokenPath)

	// If amount is 0, remove the entry; otherwise, set it.
	if amount == 0 {
		// Only attempt removal if an entry actually existed
		if found {
			tokenSpecificMinimumRewards.Remove(tokenPath)
		}
	} else {
		tokenSpecificMinimumRewards.Set(tokenPath, amount)
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetTokenMinimumRewardAmount",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"paramsStr", paramsStr, // Log the raw input string
		"tokenPath", tokenPath,
		"prevAmountFound", formatBool(found),
		"prevAmount", formatUint(prevAmount), // Will be 0 if !found
		"newAmount", formatUint(amount),
	)
}

func setDepositGnsAmount(amount uint64) {
	depositGnsAmount = amount
}

func setMinimumRewardAmount(amount uint64) {
	minimumRewardAmount = amount
}

func getDepositGnsAmount() uint64 {
	return depositGnsAmount
}

func getMinimumRewardAmount() uint64 {
	return minimumRewardAmount
}
