package common

import (
	"errors"

	"gno.land/p/nt/grc20/v0"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/nt/grc20reg/v0"
)

// commonV1 executes token operations against gno.land/r/nt/grc20reg/v0.
type commonV1 struct{}

// NewCommonV1 returns the common implementation backed by the registered GRC20
// token registry.
//
// Returns:
//   - implementation: new ICommon implementation instance
func NewCommonV1() common.ICommon {
	return &commonV1{}
}

// IsRegistered verifies that tokenKey is valid and resolves to a registered
// GRC20 token.
//
// Parameters:
//   - tokenKey: registry key identifying the token, including its realm path and symbol
//
// Returns:
//   - error: nil when the key is valid and registered; an error when validation
//     fails or no token is registered under the key
func (c *commonV1) IsRegistered(tokenKey string) error {
	if err := validateTokenKey(tokenKey); err != nil {
		return err
	}

	if grc20reg.Get(tokenKey) == nil {
		return ufmt.Errorf("token(%s) is not registered", tokenKey)
	}

	return nil
}

// ValidateRegistered verifies every supplied token key before a multi-token
// operation proceeds.
//
// Parameters:
//   - tokenKeys: token registry keys that must all be valid and registered
//
// Returns:
//   - error: nil when every key is registered; an error identifying the first
//     key that is invalid or unregistered otherwise
func (c *commonV1) ValidateRegistered(tokenKeys ...string) error {
	for _, tokenKey := range tokenKeys {
		if err := c.IsRegistered(tokenKey); err != nil {
			return errors.New(newErrorWithDetail(
				errNotRegistered,
				ufmt.Sprintf("token(%s)", tokenKey),
			))
		}
	}

	return nil
}

// TotalSupply returns the total supply recorded for a registered token.
//
// Parameters:
//   - tokenKey: registry key of the token to inspect
//
// Returns:
//   - supply: token total supply; panics when tokenKey is invalid or unregistered
func (c *commonV1) TotalSupply(tokenKey string) int64 {
	return c.mustGetToken(tokenKey).TotalSupply()
}

// BalanceOf returns the token balance held by addr.
//
// Parameters:
//   - tokenKey: registry key of the token to inspect
//   - addr: address whose token balance is queried
//
// Returns:
//   - balance: amount of tokenKey held by addr; panics when tokenKey is invalid
//     or unregistered
func (c *commonV1) BalanceOf(tokenKey string, addr address) int64 {
	return c.mustGetToken(tokenKey).BalanceOf(addr)
}

// Allowance returns the amount that spender may transfer from owner.
//
// Parameters:
//   - tokenKey: registry key of the token to inspect
//   - owner: address that granted the allowance
//   - spender: address authorized to spend from owner
//
// Returns:
//   - allowance: remaining token amount spender may transfer; panics when
//     tokenKey is invalid or unregistered
func (c *commonV1) Allowance(tokenKey string, owner, spender address) int64 {
	return c.mustGetToken(tokenKey).Allowance(owner, spender)
}

// Transfer moves amount of a registered token to to using a teller bound to rlm.
//
// Parameters:
//   - _: realm-call discriminator; callers pass 0
//   - rlm: propagated realm context used to bind the token teller and forwarded
//     for the token actor's realm validation
//   - tokenKey: registry key of the token to transfer
//   - to: recipient address
//   - amount: number of token units to transfer
//
// Returns:
//   - error: nil after a successful transfer; the token teller's validation or
//     transfer error otherwise
func (c *commonV1) Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).Transfer(0, rlm, to, amount)
}

// TransferFrom moves amount of a registered token from from to to using the
// allowance/authorization associated with the calling realm.
//
// Parameters:
//   - _: realm-call discriminator; callers pass 0
//   - rlm: propagated realm context used to bind the token teller and forwarded
//     for the token actor's realm validation
//   - tokenKey: registry key of the token to transfer
//   - from: address whose token balance is debited
//   - to: recipient address
//   - amount: number of token units to transfer
//
// Returns:
//   - error: nil after a successful transfer; the token teller's validation,
//     allowance, or balance error otherwise
func (c *commonV1) TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).TransferFrom(0, rlm, from, to, amount)
}

// Approve sets amount as the allowance that spender may use from the caller.
//
// Parameters:
//   - _: realm-call discriminator; callers pass 0
//   - rlm: propagated realm context used to bind the token teller and forwarded
//     for the token actor's realm validation
//   - tokenKey: registry key of the token to approve
//   - spender: address authorized to spend
//   - amount: maximum number of token units spender may transfer
//
// Returns:
//   - error: nil after the allowance is stored; the token teller's validation
//     error otherwise
func (c *commonV1) Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).Approve(0, rlm, spender, amount)
}

func (c *commonV1) mustGetToken(tokenKey string) *grc20.Token {
	if err := validateTokenKey(tokenKey); err != nil {
		panic(err.Error())
	}

	token := grc20reg.Get(tokenKey)
	if token == nil {
		panic(newErrorWithDetail(errNotRegistered, ufmt.Sprintf("unknown token(%s)", tokenKey)))
	}

	return token
}

// getTokenTeller binds the token actor to rlm. This is a same-realm borrow,
// so rlm stays current and the actor is the calling realm.
//
// Parameters:
//   - _: realm-call discriminator; callers pass 0
//   - rlm: propagated realm context bound to the returned teller
//   - tokenKey: registry key of the token whose teller is requested
//
// Returns:
//   - teller: token teller bound to rlm; panics when tokenKey is invalid or
//     unregistered
func (c *commonV1) getTokenTeller(_ int, rlm realm, tokenKey string) grc20.Teller {
	return c.mustGetToken(tokenKey).RealmTeller(0, rlm)
}
