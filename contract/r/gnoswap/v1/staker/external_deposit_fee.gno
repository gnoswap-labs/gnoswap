package staker

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

var (
	// depositGnsAmount is the amount of GNS required to create an external incentive.
	// This parameter can be modified through governance.
	depositGnsAmount = int64(1_000_000_000) // 1_000 GNS

	// minimumRewardAmount is the default minimum reward amount for external incentives.
	// This parameter can be modified through governance.
	minimumRewardAmount = int64(1_000_000_000) // Default 1000 (ugnot equivalent for GNS)
)

// tokenSpecificMinimumRewards stores minimum reward amounts for specific tokens.
// Key: tokenPath (string), Value: minimumAmount (int64)
var tokenSpecificMinimumRewards = avl.NewTree()

// GetDepositGnsAmount returns the current deposit amount in GNS.
func GetDepositGnsAmount() int64 {
	return depositGnsAmount
}

// GetMinimumRewardAmount returns the default minimum reward amount required for external incentives.
func GetMinimumRewardAmount() int64 {
	return minimumRewardAmount
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	amountI, found := tokenSpecificMinimumRewards.Get(tokenPath)
	if found {
		return amountI.(int64)
	}
	// Fallback to default if not found
	return GetMinimumRewardAmount()
}

// GetSpecificTokenMinimumRewardAmount returns the explicitly set minimum reward amount for a token.
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	amountI, found := tokenSpecificMinimumRewards.Get(tokenPath)
	if !found {
		return 0, false
	}
	v, ok := amountI.(int64)
	if !ok {
		panic("failed to cast amount to int64")
	}
	return v, true
}

// SetDepositGnsAmount sets the GNS deposit amount required for creating external incentives.
// Only admin or governance can call this function.
func SetDepositGnsAmount(cur realm, amount int64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidAmount(amount)

	prevDepositGnsAmount := getDepositGnsAmount()
	setDepositGnsAmount(amount)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetDepositGnsAmount",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevAmount", formatInt(prevDepositGnsAmount),
		"newAmount", formatInt(amount),
	)
}

// SetMinimumRewardAmount sets the default minimum reward amount for external incentives.
// Only admin or governance can call this function.
func SetMinimumRewardAmount(cur realm, amount int64) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidAmount(amount)

	prevMinimumRewardAmount := getMinimumRewardAmount()
	setMinimumRewardAmount(amount)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetMinimumRewardAmount",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevAmount", formatInt(prevMinimumRewardAmount),
		"newAmount", formatInt(amount),
	)
}

// SetTokenMinimumRewardAmount sets the minimum reward amount for a specific token.
// Only admin or governance can call this function.
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	halt.AssertIsNotHaltedStaker()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidRewardAmountFormat(paramsStr)

	// Parse the paramsStr
	parts := strings.SplitN(paramsStr, ":", 2)
	tokenPath := parts[0]
	amountStr := parts[1]
	amount64, err := strconv.ParseInt(amountStr, 10, 64)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("invalid amount format in params '%s': %v", paramsStr, err),
		))
	}

	prevAmount, found := GetSpecificTokenMinimumRewardAmount(tokenPath)

	// If amount is 0, remove the entry; otherwise, set it.
	if amount64 == 0 {
		// Only attempt removal if an entry actually existed
		if found {
			tokenSpecificMinimumRewards.Remove(tokenPath)
		}
	} else {
		tokenSpecificMinimumRewards.Set(tokenPath, amount64)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetTokenMinimumRewardAmount",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"paramsStr", paramsStr, // Log the raw input string
		"tokenPath", tokenPath,
		"prevAmountFound", formatBool(found),
		"prevAmount", formatInt(prevAmount), // Will be 0 if !found
		"newAmount", formatInt(amount64),
	)
}

// setDepositGnsAmount internally updates the deposit GNS amount.
func setDepositGnsAmount(amount int64) {
	depositGnsAmount = amount
}

// setMinimumRewardAmount internally updates the minimum reward amount.
func setMinimumRewardAmount(amount int64) {
	minimumRewardAmount = amount
}

// getDepositGnsAmount internally retrieves the deposit GNS amount.
func getDepositGnsAmount() int64 {
	return depositGnsAmount
}

// getMinimumRewardAmount internally retrieves the minimum reward amount.
func getMinimumRewardAmount() int64 {
	return minimumRewardAmount
}
