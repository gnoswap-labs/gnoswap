package position

import u256 "gno.land/p/gnoswap/uint256"

// Position represents a liquidity position in a pool.
// Each position tracks the amount of liquidity, fee growth, and tokens owed to the position owner.
type Position struct {
	operator  address    // address that is approved for spending this token
	poolKey   string     // poolPath of the pool which this has lp token
	tickLower int32      // the lower tick of the position, bounds are included
	tickUpper int32      // the upper tick of the position
	liquidity *u256.Uint // liquidity of the position

	// fee growth of the aggregate position as of the last action on the individual position
	feeGrowthInside0LastX128 *u256.Uint
	feeGrowthInside1LastX128 *u256.Uint

	// how many uncollected tokens are owed to the position, as of the last computation
	tokensOwed0 *u256.Uint
	tokensOwed1 *u256.Uint

	token0Balance *u256.Uint // token0 balance of the position
	token1Balance *u256.Uint // token1 balance of the position

	burned bool // whether the position has been burned (we don't burn the NFT, just mark as burned)
}

// PoolKey returns the pool path of the position.
//
// Returns:
//   - poolKey: pool path identifier
func (p *Position) PoolKey() string {
	return p.poolKey
}

// SetPoolKey sets the pool path of the position.
//
// Parameters:
//   - poolKey: pool path identifier
func (p *Position) SetPoolKey(poolKey string) {
	p.poolKey = poolKey
}

// Liquidity returns the liquidity amount of the position.
//
// Returns:
//   - liquidity: liquidity amount
func (p *Position) Liquidity() *u256.Uint {
	return p.liquidity
}

// SetLiquidity sets the liquidity amount of the position.
//
// Parameters:
//   - liquidity: liquidity amount
func (p *Position) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = liquidity
}

// TickLower returns the lower tick boundary of the position.
//
// Returns:
//   - tickLower: lower tick boundary
func (p *Position) TickLower() int32 {
	return p.tickLower
}

// SetTickLower sets the lower tick boundary of the position.
//
// Parameters:
//   - tickLower: lower tick boundary
func (p *Position) SetTickLower(tickLower int32) {
	p.tickLower = tickLower
}

// TickUpper returns the upper tick boundary of the position.
//
// Returns:
//   - tickUpper: upper tick boundary
func (p *Position) TickUpper() int32 {
	return p.tickUpper
}

// SetTickUpper sets the upper tick boundary of the position.
//
// Parameters:
//   - tickUpper: upper tick boundary
func (p *Position) SetTickUpper(tickUpper int32) {
	p.tickUpper = tickUpper
}

// TokensOwed0 returns the amount of token0 owed to the position.
//
// Returns:
//   - tokensOwed0: uncollected token0 amount
func (p *Position) TokensOwed0() *u256.Uint {
	return p.tokensOwed0
}

// SetTokensOwed0 sets the amount of token0 owed to the position.
//
// Parameters:
//   - tokensOwed0: uncollected token0 amount
func (p *Position) SetTokensOwed0(tokensOwed0 *u256.Uint) {
	p.tokensOwed0 = tokensOwed0
}

// TokensOwed1 returns the amount of token1 owed to the position.
//
// Returns:
//   - tokensOwed1: uncollected token1 amount
func (p *Position) TokensOwed1() *u256.Uint {
	return p.tokensOwed1
}

// SetTokensOwed1 sets the amount of token1 owed to the position.
//
// Parameters:
//   - tokensOwed1: uncollected token1 amount
func (p *Position) SetTokensOwed1(tokensOwed1 *u256.Uint) {
	p.tokensOwed1 = tokensOwed1
}

// Token0Balance returns the token0 balance of the position.
//
// Returns:
//   - token0Balance: token0 balance
func (p *Position) Token0Balance() *u256.Uint {
	return p.token0Balance
}

// SetToken0Balance sets the token0 balance of the position.
//
// Parameters:
//   - token0Balance: token0 balance
func (p *Position) SetToken0Balance(token0Balance *u256.Uint) {
	p.token0Balance = token0Balance
}

// Token1Balance returns the token1 balance of the position.
//
// Returns:
//   - token1Balance: token1 balance
func (p *Position) Token1Balance() *u256.Uint {
	return p.token1Balance
}

// SetToken1Balance sets the token1 balance of the position.
//
// Parameters:
//   - token1Balance: token1 balance
func (p *Position) SetToken1Balance(token1Balance *u256.Uint) {
	p.token1Balance = token1Balance
}

// FeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
//
// Returns:
//   - feeGrowth: fee growth in X128 format
func (p *Position) FeeGrowthInside0LastX128() *u256.Uint {
	return p.feeGrowthInside0LastX128
}

// SetFeeGrowthInside0LastX128 sets the last recorded fee growth inside for token0.
//
// Parameters:
//   - feeGrowthInside0LastX128: fee growth in X128 format
func (p *Position) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 *u256.Uint) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

// FeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
//
// Returns:
//   - feeGrowth: fee growth in X128 format
func (p *Position) FeeGrowthInside1LastX128() *u256.Uint {
	return p.feeGrowthInside1LastX128
}

// SetFeeGrowthInside1LastX128 sets the last recorded fee growth inside for token1.
//
// Parameters:
//   - feeGrowthInside1LastX128: fee growth in X128 format
func (p *Position) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 *u256.Uint) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

// Burned returns whether the position has been burned.
//
// Returns:
//   - burned: true if position is burned
func (p *Position) Burned() bool {
	return p.burned
}

// SetBurned sets the burned status of the position.
//
// Parameters:
//   - burned: true to mark as burned
func (p *Position) SetBurned(burned bool) {
	p.burned = burned
}

// Operator returns the operator address approved for this position.
//
// Returns:
//   - operator: approved operator address
func (p *Position) Operator() address {
	return p.operator
}

// SetOperator sets the operator address for this position.
//
// Parameters:
//   - operator: address to approve as operator
func (p *Position) SetOperator(operator address) {
	p.operator = operator
}

// IsClear reports whether the position is empty.
//
// Returns:
//   - clear: true if liquidity and tokens owed are zero
func (p *Position) IsClear() bool {
	return p.liquidity.IsZero() && p.tokensOwed0.IsZero() && p.tokensOwed1.IsZero()
}

// NewPosition creates a new Position instance.
//
// Parameters:
//   - poolKey: pool path identifier
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
//   - liquidity: liquidity amount
//   - feeGrowthInside0LastX128: fee growth for token0 in X128 format
//   - feeGrowthInside1LastX128: fee growth for token1 in X128 format
//   - tokensOwed0: uncollected token0 amount
//   - tokensOwed1: uncollected token1 amount
//   - token0Balance: token0 balance
//   - token1Balance: token1 balance
//   - burned: whether position is burned
//   - operator: approved operator address
//
// Returns:
//   - position: new Position instance
func NewPosition(
	poolKey string,
	tickLower int32,
	tickUpper int32,
	liquidity *u256.Uint,
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 *u256.Uint,
	tokensOwed0, tokensOwed1 *u256.Uint,
	token0Balance, token1Balance *u256.Uint,
	burned bool,
	operator address,
) *Position {
	return &Position{
		poolKey:                  poolKey,
		tickLower:                tickLower,
		tickUpper:                tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              tokensOwed0,
		tokensOwed1:              tokensOwed1,
		token0Balance:            token0Balance,
		token1Balance:            token1Balance,
		burned:                   burned,
		operator:                 operator,
	}
}
