package pool

import (
	"chain/runtime"
	"math"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
)

// PoolTestEnv provides a clean, stateful environment for pool tests
type PoolTestEnv struct {
	t              *testing.T
	pools          map[string]*Pool
	positions      map[string]DSLPositionInfo
	currentRealm   runtime.Realm
	currentAddress address
	adminAddr      address
	poolAddr       address
}

// DSLPositionInfo stores position metadata for DSL testing
type DSLPositionInfo struct {
	owner     address
	tickLower int32
	tickUpper int32
	liquidity *u256.Uint
}

// NewPoolTestEnv initializes the base test environment
func NewPoolTestEnv(t *testing.T) *PoolTestEnv {
	t.Helper()

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr := address("g15h3ywez2g2xqqsksm9mfkau0xz2puma2qvwmqd") // pool contract address

	// Initialize basic pool setup
	ugnotFaucet(t, adminAddr, 100_000_000_000_000)
	ugnotDeposit(t, adminAddr, 100_000_000_000_000)

	return &PoolTestEnv{
		t:              t,
		pools:          make(map[string]*Pool),
		positions:      make(map[string]DSLPositionInfo),
		currentRealm:   testing.NewUserRealm(adminAddr),
		currentAddress: adminAddr,
		adminAddr:      adminAddr,
		poolAddr:       poolAddr,
	}
}

// AsUser sets the current user context
func (e *PoolTestEnv) AsUser(user address) *PoolTestEnv {
	e.t.Helper()
	e.currentAddress = user
	e.currentRealm = testing.NewUserRealm(user)
	testing.SetOriginCaller(user)
	testing.SetRealm(e.currentRealm)
	return e
}

// AsAdmin sets admin context
func (e *PoolTestEnv) AsAdmin() *PoolTestEnv {
	e.t.Helper()
	return e.AsUser(e.adminAddr)
}

// GivenPoolCreated creates a pool with specified parameters
func (e *PoolTestEnv) GivenPoolCreated(token0, token1 string, fee uint32, sqrtPriceX96 string) *PoolTestEnv {
	e.t.Helper()

	poolKey := GetPoolPath(token0, token1, fee)
	if _, exists := e.pools[poolKey]; exists {
		return e // pool already exists
	}

	// Set pool creation fee to 0 for testing
	e.AsAdmin()
	testing.SetRealm(adminRealm)
	SetPoolCreationFee(cross, 0)

	// Create the pool
	CreatePool(cross, token0, token1, fee, sqrtPriceX96)
	pool := mustGetPool(poolKey)
	e.pools[poolKey] = pool

	return e
}

// AndUserFunded provides tokens to a user
func (e *PoolTestEnv) AndUserFunded(user address, tokens ...string) *PoolTestEnv {
	e.t.Helper()

	e.AsAdmin()
	for _, token := range tokens {
		TokenFaucet(e.t, token, user)
	}

	return e
}

// AndTokensApproved approves tokens for pool operations
func (e *PoolTestEnv) AndTokensApproved(user address, tokens ...string) *PoolTestEnv {
	e.t.Helper()

	// TokenApprove already sets the realm internally, so we don't need to set it here
	for _, token := range tokens {
		TokenApprove(e.t, token, user, e.poolAddr, maxApprove)
	}

	return e
}

// AndLiquidityProvided adds liquidity to a pool
func (e *PoolTestEnv) AndLiquidityProvided(params LiquidityParams) *PoolTestEnv {
	e.t.Helper()

	pool := e.getPool(params.token0, params.token1, params.fee)
	if pool == nil {
		e.t.Fatalf("Pool not found for %s/%s/%d", params.token0, params.token1, params.fee)
	}

	// Add liquidity
	testing.SetRealm(posRealm)
	amount0, amount1 := Mint(
		cross,
		params.token0,
		params.token1,
		params.fee,
		params.tickLower,
		params.tickUpper,
		params.amount,
		e.currentAddress,
	)

	// Store position info
	posKey := e.getPositionKey(params.token0, params.token1, params.fee, params.tickLower, params.tickUpper)
	// Store position info
	_ = amount0
	_ = amount1
	e.positions[posKey] = DSLPositionInfo{
		owner:     e.currentAddress,
		tickLower: params.tickLower,
		tickUpper: params.tickUpper,
		liquidity: u256.MustFromDecimal(params.amount),
	}

	return e
}

// WhenSwapExecuted performs a swap operation
func (e *PoolTestEnv) WhenSwapExecuted(params SwapParams) (*u256.Uint, *u256.Uint) {
	e.t.Helper()

	pool := e.getPool(params.token0, params.token1, params.fee)
	if pool == nil {
		e.t.Fatalf("Pool not found for %s/%s/%d", params.token0, params.token1, params.fee)
	}

	swapCallback := func(cur realm, amount0Delta string, amount1Delta string) error {
		testing.SetRealm(adminRealm)
		if params.zeroForOne {
			common.SafeGRC20Transfer(cross, params.token0, e.currentAddress, math.MaxInt64)
		} else {
			common.SafeGRC20Transfer(cross, params.token1, e.currentAddress, math.MaxInt64)
		}

		return nil
	}

	// Execute swap
	testing.SetRealm(rouRealm)
	amount0Str, amount1Str := Swap(
		cross,
		params.token0,
		params.token1,
		params.fee,
		e.currentAddress,
		params.zeroForOne,
		params.amountSpecified.ToString(),
		params.sqrtPriceLimitX96.ToString(),
		e.currentAddress,
		swapCallback,
	)

	return u256.MustFromDecimal(amount0Str), u256.MustFromDecimal(amount1Str)
}

// ThenPoolStateShouldBe verifies pool state
func (e *PoolTestEnv) ThenPoolStateShouldBe(token0, token1 string, fee uint32, expected PoolState) {
	e.t.Helper()

	pool := e.getPool(token0, token1, fee)
	if pool == nil {
		e.t.Fatalf("Pool not found for %s/%s/%d", token0, token1, fee)
	}

	if expected.sqrtPriceX96 != "" {
		uassert.Equal(e.t, expected.sqrtPriceX96, pool.slot0.sqrtPriceX96.ToString())
	}
	if expected.tick != 0 {
		uassert.Equal(e.t, expected.tick, pool.slot0.tick)
	}
	if expected.liquidity != "" {
		uassert.Equal(e.t, expected.liquidity, pool.liquidity.ToString())
	}
}

// Helper methods
func (e *PoolTestEnv) getPool(token0, token1 string, fee uint32) *Pool {
	poolKey := GetPoolPath(token0, token1, fee)
	return e.pools[poolKey]
}

func (e *PoolTestEnv) getPositionKey(token0, token1 string, fee uint32, tickLower, tickUpper int32) string {
	return ufmt.Sprintf("%s:%s:%d:%d:%d", token0, token1, fee, tickLower, tickUpper)
}

// LiquidityBuilder provides fluent interface for liquidity parameters
type LiquidityBuilder struct {
	params LiquidityParams
}

// LiquidityParams holds parameters for liquidity provision
type LiquidityParams struct {
	token0    string
	token1    string
	fee       uint32
	tickLower int32
	tickUpper int32
	amount    string
}

// NewLiquidityBuilder creates a new liquidity parameter builder
func NewLiquidityBuilder() *LiquidityBuilder {
	return &LiquidityBuilder{
		params: LiquidityParams{
			token0:    barPath,
			token1:    bazPath,
			fee:       3000,
			tickLower: -887220,
			tickUpper: 887220,
			amount:    "1000000",
		},
	}
}

// ForPool sets the pool parameters
func (b *LiquidityBuilder) ForPool(token0, token1 string, fee uint32) *LiquidityBuilder {
	b.params.token0 = token0
	b.params.token1 = token1
	b.params.fee = fee
	return b
}

// InRange sets the tick range
func (b *LiquidityBuilder) InRange(tickLower, tickUpper int32) *LiquidityBuilder {
	b.params.tickLower = tickLower
	b.params.tickUpper = tickUpper
	return b
}

// WithAmount sets the liquidity amount
func (b *LiquidityBuilder) WithAmount(amount string) *LiquidityBuilder {
	b.params.amount = amount
	return b
}

// Build returns the constructed liquidity parameters
func (b *LiquidityBuilder) Build() LiquidityParams {
	return b.params
}

// SwapBuilder provides fluent interface for swap parameters
type SwapBuilder struct {
	params SwapParams
}

// SwapParams holds parameters for swap operations
type SwapParams struct {
	token0            string
	token1            string
	fee               uint32
	zeroForOne        bool
	amountSpecified   *i256.Int
	sqrtPriceLimitX96 *u256.Uint
}

// NewSwapBuilder creates a new swap parameter builder
func NewSwapBuilder() *SwapBuilder {
	return &SwapBuilder{
		params: SwapParams{
			token0:            barPath,
			token1:            bazPath,
			fee:               3000,
			zeroForOne:        true,
			amountSpecified:   i256.Zero(),
			sqrtPriceLimitX96: u256.Zero(),
		},
	}
}

// InPool sets the pool for swap
func (b *SwapBuilder) InPool(token0, token1 string, fee uint32) *SwapBuilder {
	b.params.token0 = token0
	b.params.token1 = token1
	b.params.fee = fee
	return b
}

// SwapToken0For1 sets swap direction from token0 to token1
func (b *SwapBuilder) SwapToken0For1() *SwapBuilder {
	b.params.zeroForOne = true
	return b
}

// SwapToken1For0 sets swap direction from token1 to token0
func (b *SwapBuilder) SwapToken1For0() *SwapBuilder {
	b.params.zeroForOne = false
	return b
}

// ExactInput sets exact input amount
func (b *SwapBuilder) ExactInput(amount string) *SwapBuilder {
	b.params.amountSpecified = i256.MustFromDecimal(amount)
	return b
}

// ExactOutput sets exact output amount (negative)
func (b *SwapBuilder) ExactOutput(amount string) *SwapBuilder {
	b.params.amountSpecified = i256.MustFromDecimal("-" + amount)
	return b
}

// WithPriceLimit sets the price limit
func (b *SwapBuilder) WithPriceLimit(sqrtPriceX96 string) *SwapBuilder {
	b.params.sqrtPriceLimitX96 = u256.MustFromDecimal(sqrtPriceX96)
	return b
}

// Build returns the constructed swap parameters
func (b *SwapBuilder) Build() SwapParams {
	return b.params
}

// PoolState represents expected pool state for assertions
type PoolState struct {
	sqrtPriceX96 string
	tick         int32
	liquidity    string
}

// PoolBuilder provides fluent interface for pool creation
type PoolBuilder struct {
	token0       string
	token1       string
	fee          uint32
	sqrtPriceX96 string
}

// NewPoolBuilder creates a new pool builder
func NewPoolBuilder() *PoolBuilder {
	return &PoolBuilder{
		token0:       barPath,
		token1:       bazPath,
		fee:          3000,
		sqrtPriceX96: "79228162514264337593543950336", // 1:1 ratio
	}
}

// WithTokens sets the token pair
func (b *PoolBuilder) WithTokens(token0, token1 string) *PoolBuilder {
	b.token0 = token0
	b.token1 = token1
	return b
}

// WithFee sets the fee tier
func (b *PoolBuilder) WithFee(fee uint32) *PoolBuilder {
	b.fee = fee
	return b
}

// AtPrice sets the initial price
func (b *PoolBuilder) AtPrice(sqrtPriceX96 string) *PoolBuilder {
	b.sqrtPriceX96 = sqrtPriceX96
	return b
}

// Create creates the pool in the test environment
func (b *PoolBuilder) Create(env *PoolTestEnv) *PoolTestEnv {
	return env.GivenPoolCreated(b.token0, b.token1, b.fee, b.sqrtPriceX96)
}

// Assertion helpers
func assertPoolExists(t *testing.T, token0, token1 string, fee uint32) {
	t.Helper()
	poolPath := GetPoolPath(token0, token1, fee)
	uassert.True(t, ExistsPoolPath(poolPath), "Pool should exist")
}

func assertSwapSuccess(t *testing.T, amount0, amount1 *u256.Uint, expectedAmount0, expectedAmount1 string) {
	t.Helper()
	uassert.Equal(t, expectedAmount0, amount0.ToString())
	uassert.Equal(t, expectedAmount1, amount1.ToString())
}

func assertLiquidityAdded(t *testing.T, pool *Pool, expectedLiquidity string) {
	t.Helper()
	uassert.Equal(t, expectedLiquidity, pool.liquidity.ToString())
}
