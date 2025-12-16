package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

var defaultAllowed = []string{GNOT_DENOM, GNS_PATH}

// AddToken adds a new token path to the list of allowed tokens
// Only the admin can add a new token.
//
// Parameters:
//   - tokenPath (string): The path of the token to add
//
// Panics:
//   - If the caller is not the admin
func (s *stakerV1) AddToken(tokenPath string) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	if err := modifyTokenList(s, tokenPath, addTokenValidator, addTokenExecutor); err != nil {
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
func (s *stakerV1) RemoveToken(tokenPath string) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	if err := modifyTokenList(s, tokenPath, removeTokenValidator, removeTokenExecutor); err != nil {
		panic(err.Error())
	}

	chain.Emit(
		"RemoveToken",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"tokenPath", tokenPath,
	)
}

// TokenValidator is a function type that validates a token
type TokenValidator func(tokenPath string) error

// TokenExecutor is a token manipulation function type
type TokenExecutor func(tokenPath string, tokens []string) []string

// modifyTokenList handles common token modification logics, such as admin check, validation, and execution.
func modifyTokenList(s *stakerV1, tokenPath string, validator TokenValidator, executor TokenExecutor) error {
	// validate token operation if validator is provided
	if validator != nil {
		if err := validator(tokenPath); err != nil {
			return err
		}
	}

	allowedTokens := s.store.GetAllowedTokens()
	allowedTokens = executor(tokenPath, allowedTokens)
	s.store.SetAllowedTokens(allowedTokens)
	return nil
}

// addTokenExecutor executes token append operation
func addTokenExecutor(tokenPath string, tokens []string) []string {
	if contains(tokens, tokenPath) {
		return tokens
	}

	return append(tokens, tokenPath)
}

// addTokenValidator validates token addition operation
func addTokenValidator(tokenPath string) error {
	if contains(defaultAllowed, tokenPath) {
		return ufmt.Errorf("%v: cannot add existing token(%s)", errAddExistingToken, tokenPath)
	}

	return nil
}

// removeTokenExecutor executes token removal operation
func removeTokenExecutor(tokenPath string, tokens []string) []string {
	// find and remove token
	for i, t := range tokens {
		if t == tokenPath {
			return append(tokens[:i], tokens[i+1:]...)
		}
	}

	// if token not found, return the original list
	return tokens
}

// removeTokenValidator validates token removal operation
func removeTokenValidator(tokenPath string) error {
	if contains(defaultAllowed, tokenPath) {
		return ufmt.Errorf("%v: cannot remove default token(%s)", errDefaultExternalToken, tokenPath)
	}

	return nil
}
