package staker

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

// AddToken adds a registered token key to the list of allowed tokens.
// Only admin or governance can add a token.
//
// Parameters:
//   - tokenPath (string): The registered token key to add
//
// Panics:
//   - If the caller is not admin or governance, or the token key is not registered
func (s *stakerV1) AddToken(_ int, rlm realm, tokenPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	if err := checkCannotAddDefaultToken(tokenPath); err != nil {
		panic(err.Error())
	}

	common.MustRegistered(tokenPath)

	if err := s.store.AddAllowedToken(0, rlm, tokenPath); err != nil {
		panic(err.Error())
	}

	chain.Emit(
		"AddToken",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", tokenPath,
	)
}

// RemoveToken removes a token path from the list of allowed tokens.
// Only the admin  can remove a token.
//
// Default tokens cannot be removed.
//
// Parameters:
//   - tokenPath (string): The path of the token to remove
//
// Panics:
//   - If the caller is not the admin
func (s *stakerV1) RemoveToken(_ int, rlm realm, tokenPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	if err := checkCannotRemoveDefaultToken(tokenPath); err != nil {
		panic(err.Error())
	}

	if err := s.store.RemoveAllowedToken(0, rlm, tokenPath); err != nil {
		panic(err.Error())
	}

	chain.Emit(
		"RemoveToken",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", tokenPath,
	)
}

func checkCannotAddDefaultToken(tokenPath string) error {
	if contains(sr.DefaultAllowedTokens(), tokenPath) {
		return ufmt.Errorf("%v: cannot add existing token(%s)", errAddExistingToken, tokenPath)
	}

	return nil
}

func checkCannotRemoveDefaultToken(tokenPath string) error {
	if contains(sr.DefaultAllowedTokens(), tokenPath) {
		return ufmt.Errorf("%v: cannot remove default token(%s)", errDefaultExternalToken, tokenPath)
	}

	return nil
}
