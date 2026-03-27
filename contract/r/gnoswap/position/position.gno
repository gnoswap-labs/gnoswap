package position

// Position represents a liquidity position in a pool.
// Each position tracks the amount of liquidity, fee growth, and tokens owed to the position owner.
// All uint256 fields are stored as decimal strings to reduce realm object overhead.
type Position struct {
	operator  address // address that is approved for spending this token
	poolKey   string  // poolPath of the pool which this has lp token
	tickLower int32   // the lower tick of the position, bounds are included
	tickUpper int32   // the upper tick of the position
	liquidity string  // liquidity of the position

	// fee growth of the aggregate position as of the last action on the individual position
	feeGrowthInside0LastX128 string
	feeGrowthInside1LastX128 string

	// how many uncollected tokens are owed to the position, as of the last computation
	tokensOwed0 int64
	tokensOwed1 int64

	token0Balance int64 // token0 balance of the position
	token1Balance int64 // token1 balance of the position

	burned bool // whether the position has been burned (we don't burn the NFT, just mark as burned)
}

func (p *Position) PoolKey() string {
	return p.poolKey
}

func (p *Position) SetPoolKey(poolKey string) {
	p.poolKey = poolKey
}

func (p *Position) Liquidity() string {
	return p.liquidity
}

func (p *Position) SetLiquidity(liquidity string) {
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

func (p *Position) TokensOwed0() int64 {
	return p.tokensOwed0
}

func (p *Position) SetTokensOwed0(tokensOwed0 int64) {
	p.tokensOwed0 = tokensOwed0
}

func (p *Position) TokensOwed1() int64 {
	return p.tokensOwed1
}

func (p *Position) SetTokensOwed1(tokensOwed1 int64) {
	p.tokensOwed1 = tokensOwed1
}

func (p *Position) Token0Balance() int64 {
	return p.token0Balance
}

func (p *Position) SetToken0Balance(token0Balance int64) {
	p.token0Balance = token0Balance
}

func (p *Position) Token1Balance() int64 {
	return p.token1Balance
}

func (p *Position) SetToken1Balance(token1Balance int64) {
	p.token1Balance = token1Balance
}

func (p *Position) FeeGrowthInside0LastX128() string {
	return p.feeGrowthInside0LastX128
}

func (p *Position) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 string) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

func (p *Position) FeeGrowthInside1LastX128() string {
	return p.feeGrowthInside1LastX128
}

func (p *Position) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 string) {
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
	return isZeroStr(p.liquidity) && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}

func isZeroStr(s string) bool {
	return s == "" || s == "0"
}

func NewPosition(
	poolKey string,
	tickLower int32,
	tickUpper int32,
	liquidity string,
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 string,
	tokensOwed0, tokensOwed1 int64,
	token0Balance, token1Balance int64,
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
