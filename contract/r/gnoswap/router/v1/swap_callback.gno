package router

import (
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
)

// SwapCallback implements the pool's SwapCallback interface.
// The pool invokes it after sending output tokens; the router then transfers the
// positive input delta to the pool.
//
// Parameters:
//   - _: leading callback discriminator; callers pass 0
//   - rlm: propagated current realm context; must remain the current crossing frame
//   - token0Path: token-0 contract path in canonical pool order
//   - token1Path: token-1 contract path in canonical pool order
//   - amount0Delta: signed token-0 delta; positive means the pool is owed this amount
//   - amount1Delta: signed token-1 delta; positive means the pool is owed this amount
//   - payer: address whose balance supplies the positive input delta
//
// Returns:
//   - err: nil after the owed input transfer; an error for spoofed realm, invalid liquidity delta, or failed payment
//
// Positive deltas are tokens the pool must receive; negative deltas are tokens
// the pool has sent to the recipient.
func (r *routerV1) SwapCallback(
	_ int,
	rlm realm,
	token0Path, token1Path string,
	amount0Delta, amount1Delta int64,
	payer address,
) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	if amount0Delta <= 0 && amount1Delta <= 0 {
		return makeErrorWithDetails(
			errInsufficientLiquidity,
			"swap entirely within 0-liquidity region",
		)
	}

	halt.AssertIsNotHaltedRouter()

	caller := rlm.Previous().Address()
	assertIsRouterImplementation(caller)

	var tokenToPay string
	var amountToPay int64

	// amount0Delta > 0 means pool wants token0
	// amount1Delta > 0 means pool wants token1
	if amount0Delta > 0 {
		amountToPay = amount0Delta
		tokenToPay = token0Path
	} else {
		amountToPay = amount1Delta
		tokenToPay = token1Path
	}

	// Transfer tokens from router to pool
	// The router should already have the tokens from the user
	r.transferToPool(0, rlm, tokenToPay, u256.NewUintFromInt64(amountToPay), payer)

	return nil
}

// transferToPool transfers an owed input amount from payer to the pool.
//
// Parameters:
//   - _: leading callback discriminator; callers pass 0
//   - rlm: propagated current realm context used for token transfer authorization
//   - token: token contract path to transfer
//   - amount: positive token amount owed to the pool
//   - payer: address whose balance is debited; the router address uses a direct transfer
func (r *routerV1) transferToPool(_ int, rlm realm, token string, amount *u256.Uint, payer address) {
	balance := common.BalanceOf(token, payer)

	if u256.NewUintFromInt64(balance).Lt(amount) {
		panic(makeErrorWithDetails(
			errInsufficientBalance,
			ufmt.Sprintf("token=%s, required=%d, available=%d, payer=%s", token, amount.Int64(), balance, payer.String()),
		))
	}

	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())

	if payer == routerAddr {
		common.SafeGRC20Transfer(0, rlm, token, poolAddr, amount.Int64())
	} else {
		common.SafeGRC20TransferFrom(0, rlm, token, payer, poolAddr, amount.Int64())
	}
}
