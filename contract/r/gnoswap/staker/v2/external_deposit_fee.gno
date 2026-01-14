package v2

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

// GetDepositGnsAmount returns the current deposit amount in GNS.
func (s *stakerV1) GetDepositGnsAmount() int64 {
	return s.store.GetDepositGnsAmount()
}

// GetMinimumRewardAmount returns the default minimum reward amount required for external incentives.
func (s *stakerV1) GetMinimumRewardAmount() int64 {
	return s.store.GetMinimumRewardAmount()
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
func (s *stakerV1) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	amountI, found := s.store.GetTokenSpecificMinimumRewards().Get(tokenPath)
	if found {
		amount, ok := amountI.(int64)
		if !ok {
			panic("failed to cast amount to int64")
		}
		return amount
	}
	// Fallback to default if not found
	return s.GetMinimumRewardAmount()
}

// GetSpecificTokenMinimumRewardAmount returns the explicitly set minimum reward amount for a token.
func (s *stakerV1) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	amountI, found := s.store.GetTokenSpecificMinimumRewards().Get(tokenPath)
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
func (s *stakerV1) SetDepositGnsAmount(amount int64) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidAmount(amount)

	prevDepositGnsAmount := s.GetDepositGnsAmount()
	s.setDepositGnsAmount(amount)

	chain.Emit(
		"SetDepositGnsAmount",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevAmount", formatAnyInt(prevDepositGnsAmount),
		"newAmount", formatAnyInt(amount),
	)
}

// SetMinimumRewardAmount sets the default minimum reward amount for external incentives.
// Only admin or governance can call this function.
func (s *stakerV1) SetMinimumRewardAmount(amount int64) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidAmount(amount)

	prevMinimumRewardAmount := s.getMinimumRewardAmount()
	amount = amount * 10
	s.setMinimumRewardAmount(amount)

	chain.Emit(
		"SetMinimumRewardAmount",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevAmount", formatAnyInt(prevMinimumRewardAmount),
		"newAmount", formatAnyInt(amount),
	)
}

// SetTokenMinimumRewardAmount sets the minimum reward amount for a specific token.
// Only admin or governance can call this function.
func (s *stakerV1) SetTokenMinimumRewardAmount(paramsStr string) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
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

	prevAmount, found := s.GetSpecificTokenMinimumRewardAmount(tokenPath)

	// If amount is 0, remove the entry; otherwise, set it.
	if amount64 == 0 {
		// Only attempt removal if an entry actually existed
		if found {
			s.store.GetTokenSpecificMinimumRewards().Remove(tokenPath)
		}
	} else {
		s.store.GetTokenSpecificMinimumRewards().Set(tokenPath, amount64)
	}

	chain.Emit(
		"SetTokenMinimumRewardAmount",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"paramsStr", paramsStr, // Log the raw input string
		"tokenPath", tokenPath,
		"prevAmountFound", formatBool(found),
		"prevAmount", formatAnyInt(prevAmount), // Will be 0 if !found
		"newAmount", formatAnyInt(amount64),
	)
}

// setDepositGnsAmount internally updates the deposit GNS amount.
func (s *stakerV1) setDepositGnsAmount(amount int64) {
	s.store.SetDepositGnsAmount(amount)
}

// setMinimumRewardAmount internally updates the minimum reward amount.
func (s *stakerV1) setMinimumRewardAmount(amount int64) {
	s.store.SetMinimumRewardAmount(amount)
}

// getMinimumRewardAmount internally retrieves the minimum reward amount.
func (s *stakerV1) getMinimumRewardAmount() int64 {
	return s.store.GetMinimumRewardAmount()
}
