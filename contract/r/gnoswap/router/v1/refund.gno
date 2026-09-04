package router

import (
	"chain"
	"strings"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
)

// routerFundsSnapshot captures the router's balance and pending protocol fee per
// route token before a swap, so only surpluses accrued during the swap are
// refunded — never funds the router held beforehand.
type routerFundsSnapshot struct {
	tokens      []string
	balances    map[string]int64
	pendingFees map[string]int64
}

// collectRouteTokens returns the distinct token paths in routeArr in order of
// first appearance. routeArr must already be validated by the entry points.
func collectRouteTokens(routeArr string) []string {
	seen := make(map[string]bool)
	tokens := make([]string, 0)

	appendToken := func(token string) {
		if !seen[token] {
			seen[token] = true
			tokens = append(tokens, token)
		}
	}

	for _, route := range strings.Split(routeArr, ",") {
		for _, poolPath := range strings.Split(route, POOL_SEPARATOR) {
			tokenIn, tokenOut, _, err := getDataForSinglePathWithError(poolPath)
			if err != nil {
				panic(err)
			}

			appendToken(tokenIn)
			appendToken(tokenOut)
		}
	}

	return tokens
}

// captureFundsSnapshot must run before the swap moves any funds.
func (r *routerV1) captureFundsSnapshot(routeArr string) *routerFundsSnapshot {
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	pendingProtocolFees := r.store.GetPendingProtocolFees()

	snapshot := &routerFundsSnapshot{
		tokens:      collectRouteTokens(routeArr),
		balances:    make(map[string]int64),
		pendingFees: make(map[string]int64),
	}

	for _, token := range snapshot.tokens {
		snapshot.balances[token] = common.BalanceOf(token, routerAddr)
		snapshot.pendingFees[token] = pendingProtocolFees[token]
	}

	return snapshot
}

// refundLeftovers sends the caller every route-token surplus accrued in the
// router beyond the snapshot, excluding amounts that became pending protocol
// fees during the same swap. It must run after all state updates and payouts
// of the swap, as the final interaction of the call.
func (r *routerV1) refundLeftovers(_ int, rlm realm, snapshot *routerFundsSnapshot, caller address) {
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	pendingProtocolFees := r.store.GetPendingProtocolFees()

	previousRealm := rlm.Previous()

	for _, token := range snapshot.tokens {
		balanceDelta := gnsmath.SafeSubInt64(common.BalanceOf(token, routerAddr), snapshot.balances[token])
		pendingFeeDelta := gnsmath.SafeSubInt64(pendingProtocolFees[token], snapshot.pendingFees[token])

		leftover := gnsmath.SafeSubInt64(balanceDelta, pendingFeeDelta)
		if leftover <= 0 {
			continue
		}

		common.SafeGRC20Transfer(0, rlm, token, caller, leftover)

		chain.Emit(
			"SwapRouteRefund",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"tokenPath", token,
			"amount", utils.FormatInt(leftover),
			"recipient", caller.String(),
		)
	}
}
