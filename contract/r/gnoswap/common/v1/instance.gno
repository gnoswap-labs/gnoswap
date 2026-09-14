package common

import (
	"gno.land/p/nt/grc20/v0"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/nt/grc20reg/v0"
)

// commonV1 executes token operations against gno.land/r/nt/grc20reg/v0.
type commonV1 struct{}

func NewCommonV1() common.ICommon {
	return &commonV1{}
}

func (c *commonV1) IsRegistered(tokenKey string) bool {
	return grc20reg.Get(tokenKey) != nil
}

func (c *commonV1) TotalSupply(tokenKey string) int64 {
	return c.mustGetToken(tokenKey).TotalSupply()
}

func (c *commonV1) BalanceOf(tokenKey string, addr address) int64 {
	return c.mustGetToken(tokenKey).BalanceOf(addr)
}

func (c *commonV1) Allowance(tokenKey string, owner, spender address) int64 {
	return c.mustGetToken(tokenKey).Allowance(owner, spender)
}

func (c *commonV1) Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).Transfer(0, rlm, to, amount)
}

func (c *commonV1) TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).TransferFrom(0, rlm, from, to, amount)
}

func (c *commonV1) Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return c.getTokenTeller(0, rlm, tokenKey).Approve(0, rlm, spender, amount)
}

func (c *commonV1) mustGetToken(tokenKey string) *grc20.Token {
	token := grc20reg.Get(tokenKey)
	if token == nil {
		panic(newErrorWithDetail(errNotRegistered, ufmt.Sprintf("unknown token(%s)", tokenKey)))
	}

	return token
}

// getTokenTeller binds the token actor to rlm. This is a same-realm borrow,
// so rlm stays current and the actor is the calling realm.
func (c *commonV1) getTokenTeller(_ int, rlm realm, tokenKey string) grc20.Teller {
	return c.mustGetToken(tokenKey).RealmTeller(0, rlm)
}
