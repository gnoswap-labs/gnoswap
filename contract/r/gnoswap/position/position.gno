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

func (p *Position) PoolKey() string {
	return p.poolKey
}

func (p *Position) SetPoolKey(poolKey string) {
	p.poolKey = poolKey
}

func (p *Position) Liquidity() *u256.Uint {
	return p.liquidity
}

func (p *Position) SetLiquidity(liquidity *u256.Uint) {
	p.liquidity = liquidity
}

func (p *Position) TickLower() int32 {
	return p.tickLower
}

func (p *Position) SetTickLower(tickLower int32) {
	p.tickLower = tickLower
}

func (p *Position) TickUpper() int32 {
	return p.tickUpper
}

func (p *Position) SetTickUpper(tickUpper int32) {
	p.tickUpper = tickUpper
}

func (p *Position) TokensOwed0() *u256.Uint {
	return p.tokensOwed0
}

func (p *Position) SetTokensOwed0(tokensOwed0 *u256.Uint) {
	p.tokensOwed0 = tokensOwed0
}

func (p *Position) TokensOwed1() *u256.Uint {
	return p.tokensOwed1
}

func (p *Position) SetTokensOwed1(tokensOwed1 *u256.Uint) {
	p.tokensOwed1 = tokensOwed1
}

func (p *Position) Token0Balance() *u256.Uint {
	return p.token0Balance
}

func (p *Position) SetToken0Balance(token0Balance *u256.Uint) {
	p.token0Balance = token0Balance
}

func (p *Position) Token1Balance() *u256.Uint {
	return p.token1Balance
}

func (p *Position) SetToken1Balance(token1Balance *u256.Uint) {
	p.token1Balance = token1Balance
}

func (p *Position) FeeGrowthInside0LastX128() *u256.Uint {
	return p.feeGrowthInside0LastX128
}

func (p *Position) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 *u256.Uint) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

func (p *Position) FeeGrowthInside1LastX128() *u256.Uint {
	return p.feeGrowthInside1LastX128
}

func (p *Position) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 *u256.Uint) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

func (p *Position) Burned() bool {
	return p.burned
}

func (p *Position) SetBurned(burned bool) {
	p.burned = burned
}

func (p *Position) Operator() address {
	return p.operator
}

func (p *Position) SetOperator(operator address) {
	p.operator = operator
}

// isClear reports whether the position is empty
func (p *Position) IsClear() bool {
	return p.liquidity.IsZero() && p.tokensOwed0.IsZero() && p.tokensOwed1.IsZero()
}

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
