package router

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

// TestEnv provides a clean, stateful environment for router tests
type TestEnv struct {
	t          *testing.T
	routerAddr std.Address
	pools      map[string]bool // track created pools
	positions  map[uint64]bool // track created positions
	users      map[std.Address]bool
}

// NewTestEnv initializes the base test environment
func NewTestEnv(t *testing.T) *TestEnv {
	t.Helper()
	initRouterTest(t)

	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	return &TestEnv{
		t:          t,
		routerAddr: routerAddr,
		pools:      make(map[string]bool),
		positions:  make(map[uint64]bool),
		users:      make(map[std.Address]bool),
	}
}

// GivenPoolCreated creates a pool with specified parameters
func (e *TestEnv) GivenPoolCreated(token0, token1 string, fee uint32, sqrtPriceX96 string) *TestEnv {
	e.t.Helper()

	poolKey := getPoolKey(token0, token1, fee)
	if e.pools[poolKey] {
		return e // pool already exists
	}

	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	CreatePool(e.t, token0, token1, fee, sqrtPriceX96, adminAddr)
	e.pools[poolKey] = true

	return e
}

// AndUserFundedAndApproved provides tokens and sets up approvals for a user
func (e *TestEnv) AndUserFundedAndApproved(user std.Address, routerAddr std.Address, tokens ...string) *TestEnv {
	e.t.Helper()
	userRealm := std.NewUserRealm(user)
	testing.SetRealm(userRealm)

	for _, token := range tokens {
		TokenFaucet(e.t, token, user)
		switch token {
		case barPath:
			bar.Approve(cross, routerAddr, maxApprove)
		case bazPath:
			baz.Approve(cross, routerAddr, maxApprove)
		case quxPath:
			qux.Approve(cross, routerAddr, maxApprove)
		}
	}
	e.users[user] = true

	return e
}

// AndPositionMinted creates a position with liquidity
func (e *TestEnv) AndPositionMinted() *TestEnv {
	e.t.Helper()
	MakeMintPositionWithoutFee(e.t)
	return e
}

// AndLiquidityProvided adds liquidity to a pool
func (e *TestEnv) AndLiquidityProvided(provider std.Address, params PositionParams) *TestEnv {
	e.t.Helper()

	providerRealm := std.NewUserRealm(provider)
	testing.SetRealm(providerRealm)

	// Create position with provided parameters
	tokenId, _, _, _ := pn.Mint(
		cross,
		params.token0,
		params.token1,
		params.fee,
		params.tickLower,
		params.tickUpper,
		params.amount0Desired.ToString(),
		params.amount1Desired.ToString(),
		params.amount0Min.ToString(),
		params.amount1Min.ToString(),
		9999999999, // deadline
		provider,
		provider,
		"", // data
	)

	e.positions[tokenId] = true

	return e
}

// SwapBuilder provides a fluent interface for constructing swap parameters
type SwapBuilder struct {
	params SingleSwapParams
	multi  bool
	pools  []PoolRoute
}

// NewSwapBuilder creates a new swap parameter builder
func NewSwapBuilder() *SwapBuilder {
	return &SwapBuilder{
		params: SingleSwapParams{
			amountSpecified: i256.Zero(),
		},
		multi: false,
		pools: []PoolRoute{},
	}
}

// From sets the input token
func (b *SwapBuilder) From(token string) *SwapBuilder {
	b.params.tokenIn = token
	return b
}

// To sets the output token
func (b *SwapBuilder) To(token string) *SwapBuilder {
	b.params.tokenOut = token
	return b
}

// WithFee sets the pool fee tier
func (b *SwapBuilder) WithFee(fee uint32) *SwapBuilder {
	b.params.fee = fee
	return b
}

// ExactInput sets exact input amount
func (b *SwapBuilder) ExactInput(amount string) *SwapBuilder {
	b.params.amountSpecified = i256.MustFromDecimal(amount)
	return b
}

// ExactOutput sets exact output amount (negative value)
func (b *SwapBuilder) ExactOutput(amount string) *SwapBuilder {
	negAmount := "-" + amount
	b.params.amountSpecified = i256.MustFromDecimal(negAmount)
	return b
}

// Through adds an intermediate pool for multi-hop swaps
func (b *SwapBuilder) Through(intermediateToken string, fee uint32) *SwapBuilder {
	b.multi = true
	b.pools = append(b.pools, PoolRoute{
		tokenOut: intermediateToken,
		fee:      fee,
	})
	return b
}

// Build returns the constructed parameters
func (b *SwapBuilder) Build() SingleSwapParams {
	return b.params
}

// BuildMulti returns parameters for multi-hop swap
func (b *SwapBuilder) BuildMulti() (SwapParams, string) {
	swapPath := buildSwapPath(b.params.tokenIn, b.pools, b.params.tokenOut, b.params.fee)

	return SwapParams{
		recipient:        alice, // default recipient
		SingleSwapParams: b.params,
	}, swapPath
}

// PositionBuilder provides a fluent interface for position parameters
type PositionBuilder struct {
	params PositionParams
}

// PositionParams holds parameters for position creation
type PositionParams struct {
	token0         string
	token1         string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired *u256.Uint
	amount1Desired *u256.Uint
	amount0Min     *u256.Uint
	amount1Min     *u256.Uint
}

// NewPositionBuilder creates a position parameter builder
func NewPositionBuilder() *PositionBuilder {
	return &PositionBuilder{
		params: PositionParams{
			token0:         barPath,
			token1:         bazPath,
			fee:            3000,
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: u256.Zero(),
			amount1Desired: u256.Zero(),
			amount0Min:     u256.Zero(),
			amount1Min:     u256.Zero(),
		},
	}
}

// Tokens sets the token pair
func (b *PositionBuilder) Tokens(token0, token1 string) *PositionBuilder {
	b.params.token0, b.params.token1 = token0, token1
	return b
}

// Fee sets the fee tier
func (b *PositionBuilder) Fee(fee uint32) *PositionBuilder {
	b.params.fee = fee
	return b
}

// Range sets the tick range
func (b *PositionBuilder) Range(tickLower, tickUpper int32) *PositionBuilder {
	b.params.tickLower, b.params.tickUpper = tickLower, tickUpper
	return b
}

// Amounts sets desired amounts
func (b *PositionBuilder) Amounts(amount0, amount1 string) *PositionBuilder {
	b.params.amount0Desired = u256.MustFromDecimal(amount0)
	b.params.amount1Desired = u256.MustFromDecimal(amount1)
	return b
}

// MinAmounts sets minimum amounts for slippage protection
func (b *PositionBuilder) MinAmounts(min0, min1 string) *PositionBuilder {
	b.params.amount0Min = u256.MustFromDecimal(min0)
	b.params.amount1Min = u256.MustFromDecimal(min1)
	return b
}

// Build returns the constructed position parameters
func (b *PositionBuilder) Build() PositionParams {
	return b.params
}

// PoolRoute represents a pool in a multi-hop swap path
type PoolRoute struct {
	tokenOut string
	fee      uint32
}

// Helper function to build swap path string
func buildSwapPath(tokenIn string, routes []PoolRoute, finalToken string, finalFee uint32) string {
	if len(routes) == 0 {
		return ""
	}

	path := tokenIn
	for _, route := range routes {
		path += ":" + route.tokenOut + ":" + uintToStr(route.fee) + "*POOL*" + route.tokenOut
	}
	path += ":" + finalToken + ":" + uintToStr(finalFee)

	return path
}

// Helper function to get pool key
func getPoolKey(token0, token1 string, fee uint32) string {
	if token0 > token1 {
		token0, token1 = token1, token0
	}
	return token0 + ":" + token1 + ":" + uintToStr(fee)
}

// Helper function to convert uint to string
func uintToStr(n uint32) string {
	return ufmt.Sprintf("%d", n)
}

// Assertion helpers
func assertSwapOK(t *testing.T, expectedIn, expectedOut string, actualIn, actualOut *u256.Uint) {
	t.Helper()
	uassert.Equal(t, expectedIn, actualIn.ToString())
	uassert.Equal(t, expectedOut, actualOut.ToString())
}

func assertSwapFails(t *testing.T, expectedMsg string, swapFn func()) {
	t.Helper()
	uassert.PanicsWithMessage(t, expectedMsg, swapFn)
}

// SingleSwapParamsBuilder provides fluent interface for building swap parameters
type SingleSwapParamsBuilder struct {
	p SingleSwapParams
}

// NewSingleSwapParams creates a new builder with defaults
func NewSingleSwapParams() *SingleSwapParamsBuilder {
	return &SingleSwapParamsBuilder{
		p: SingleSwapParams{
			tokenIn:         barPath,
			tokenOut:        bazPath,
			fee:             3000,
			amountSpecified: i256.Zero(),
		},
	}
}

// TokenIn sets the input token
func (b *SingleSwapParamsBuilder) TokenIn(token string) *SingleSwapParamsBuilder {
	b.p.tokenIn = token
	return b
}

// TokenOut sets the output token
func (b *SingleSwapParamsBuilder) TokenOut(token string) *SingleSwapParamsBuilder {
	b.p.tokenOut = token
	return b
}

// Fee sets the pool fee
func (b *SingleSwapParamsBuilder) Fee(fee uint32) *SingleSwapParamsBuilder {
	b.p.fee = fee
	return b
}

// ExactInput sets exact input amount
func (b *SingleSwapParamsBuilder) ExactInput(amount string) *SingleSwapParamsBuilder {
	b.p.amountSpecified = i256.MustFromDecimal(amount)
	return b
}

// ExactOutput sets exact output amount (negative)
func (b *SingleSwapParamsBuilder) ExactOutput(amount string) *SingleSwapParamsBuilder {
	b.p.amountSpecified = i256.MustFromDecimal("-" + amount)
	return b
}

// Build returns the constructed parameters
func (b *SingleSwapParamsBuilder) Build() SingleSwapParams {
	return b.p
}
