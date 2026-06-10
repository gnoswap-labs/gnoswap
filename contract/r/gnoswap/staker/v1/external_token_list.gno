package v1

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

var defaultAllowed = []string{WUGNOT_PATH, GNS_PATH}

// AddToken adds a new token path to the list of allowed tokens
// Only the admin can add a new token.
//
// Parameters:
//   - tokenPath (string): The path of the token to add
//
// Panics:
//   - If the caller is not the admin
func (s *stakerV1) AddToken(_ int, rlm realm, tokenPath string) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	if err := checkCannotAddDefaultToken(tokenPath); err != nil {
		panic(err.Error())
	}

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
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

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
	if contains(defaultAllowed, tokenPath) {
		return ufmt.Errorf("%v: cannot add existing token(%s)", errAddExistingToken, tokenPath)
	}

	return nil
}

func checkCannotRemoveDefaultToken(tokenPath string) error {
	if contains(defaultAllowed, tokenPath) {
		return ufmt.Errorf("%v: cannot remove default token(%s)", errDefaultExternalToken, tokenPath)
	}

	return nil
}
