package position

import bptree "gno.land/p/nt/bptree/v0"

// Position represents a liquidity position in a pool.
// Each position tracks liquidity, fee-growth checkpoints, tokens owed, and a
// burned marker for the position NFT.
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

	burned bool // empty-position marker; the NFT itself is not burned
}

// PoolKey returns the pool identifier associated with the position.
//
// Returns:
//   - poolKey: pool key encoding the position's token pair and fee tier
func (p *Position) PoolKey() string {
	return p.poolKey
}

// SetPoolKey stores the pool identifier associated with the position.
//
// Parameters:
//   - poolKey: pool key encoding the position's token pair and fee tier
func (p *Position) SetPoolKey(poolKey string) {
	p.poolKey = poolKey
}

// Liquidity returns the position's stored liquidity amount.
//
// Returns:
//   - liquidity: decimal-encoded liquidity currently held by the position
func (p *Position) Liquidity() string {
	return p.liquidity
}

// SetLiquidity stores the position's liquidity amount.
//
// Parameters:
//   - liquidity: decimal string representing the position's liquidity
func (p *Position) SetLiquidity(liquidity string) {
	p.liquidity = liquidity
}

// TickLower returns the lower tick boundary of the position's range.
//
// Returns:
//   - tickLower: lower tick boundary, inclusive in range checks
func (p *Position) TickLower() int32 {
	return p.tickLower
}

// SetTickLower stores the lower tick boundary of the position's range.
//
// Parameters:
//   - tickLower: lower tick boundary used for the position's range
func (p *Position) SetTickLower(tickLower int32) {
	p.tickLower = tickLower
}

// TickUpper returns the upper tick boundary of the position's range.
//
// Returns:
//   - tickUpper: upper tick boundary, used as the exclusive end in range checks
func (p *Position) TickUpper() int32 {
	return p.tickUpper
}

// SetTickUpper stores the upper tick boundary of the position's range.
//
// Parameters:
//   - tickUpper: upper tick boundary used for the position's range
func (p *Position) SetTickUpper(tickUpper int32) {
	p.tickUpper = tickUpper
}

// TokensOwed0 returns the stored amount of token0 owed to the position.
//
// Returns:
//   - tokensOwed0: accrued token0 amount awaiting collection, in token units
func (p *Position) TokensOwed0() int64 {
	return p.tokensOwed0
}

// SetTokensOwed0 stores the amount of token0 owed to the position.
//
// Parameters:
//   - tokensOwed0: accrued token0 amount awaiting collection, in token units
func (p *Position) SetTokensOwed0(tokensOwed0 int64) {
	p.tokensOwed0 = tokensOwed0
}

// TokensOwed1 returns the stored amount of token1 owed to the position.
//
// Returns:
//   - tokensOwed1: accrued token1 amount awaiting collection, in token units
func (p *Position) TokensOwed1() int64 {
	return p.tokensOwed1
}

// SetTokensOwed1 stores the amount of token1 owed to the position.
//
// Parameters:
//   - tokensOwed1: accrued token1 amount awaiting collection, in token units
func (p *Position) SetTokensOwed1(tokensOwed1 int64) {
	p.tokensOwed1 = tokensOwed1
}

// FeeGrowthInside0LastX128 returns the token0 fee-growth checkpoint.
//
// Returns:
//   - feeGrowthInside0LastX128: decimal-encoded Q128 fee growth inside the position's range at its last update
func (p *Position) FeeGrowthInside0LastX128() string {
	return p.feeGrowthInside0LastX128
}

// SetFeeGrowthInside0LastX128 stores the token0 fee-growth checkpoint.
//
// Parameters:
//   - feeGrowthInside0LastX128: decimal-encoded Q128 fee growth inside the position's range
func (p *Position) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 string) {
	p.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
}

// FeeGrowthInside1LastX128 returns the token1 fee-growth checkpoint.
//
// Returns:
//   - feeGrowthInside1LastX128: decimal-encoded Q128 fee growth inside the position's range at its last update
func (p *Position) FeeGrowthInside1LastX128() string {
	return p.feeGrowthInside1LastX128
}

// SetFeeGrowthInside1LastX128 stores the token1 fee-growth checkpoint.
//
// Parameters:
//   - feeGrowthInside1LastX128: decimal-encoded Q128 fee growth inside the position's range
func (p *Position) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 string) {
	p.feeGrowthInside1LastX128 = feeGrowthInside1LastX128
}

// Burned reports the position's empty-position marker.
//
// Returns:
//   - burned: true when the position is marked empty after its balances clear; the position NFT itself is not burned
func (p *Position) Burned() bool {
	return p.burned
}

// SetBurned stores the position's empty-position marker.
//
// Parameters:
//   - burned: marker indicating whether the position is considered empty
func (p *Position) SetBurned(burned bool) {
	p.burned = burned
}

// Operator returns the address approved to operate on the position.
//
// Returns:
//   - operator: approved operator address, or the empty address when no operator is set
func (p *Position) Operator() address {
	return p.operator
}

// SetOperator stores the address approved to operate on the position.
//
// Parameters:
//   - operator: approved operator address; the empty address removes the operator
func (p *Position) SetOperator(operator address) {
	p.operator = operator
}

// IsClear reports whether liquidity and tokens owed are all zero; it does not
// describe the burned marker.
//
// Returns:
//   - clear: true when stored liquidity and both token-owed counters are zero, regardless of the burned marker
func (p *Position) IsClear() bool {
	return isZeroStr(p.liquidity) && p.tokensOwed0 == 0 && p.tokensOwed1 == 0
}

// isZeroStr reports whether a stored decimal string uses either supported zero representation.
//
// Parameters:
//   - s: decimal string to compare with the empty and canonical zero representations
//
// Returns:
//   - isZero: true only when s is empty or exactly "0"
func isZeroStr(s string) bool {
	return s == "" || s == "0"
}

// NewPosition constructs a position from its persisted pool, range, liquidity,
// fee-growth, owed-token, marker, and operator values.
//
// Parameters:
//   - poolKey: pool key encoding the position's token pair and fee tier
//   - tickLower: lower tick boundary of the position's range
//   - tickUpper: upper tick boundary of the position's range
//   - liquidity: decimal string representing the position's liquidity
//   - feeGrowthInside0LastX128: decimal-encoded Q128 token0 fee-growth checkpoint
//   - feeGrowthInside1LastX128: decimal-encoded Q128 token1 fee-growth checkpoint
//   - tokensOwed0: accrued token0 amount awaiting collection, in token units
//   - tokensOwed1: accrued token1 amount awaiting collection, in token units
//   - burned: empty-position marker to store
//   - operator: approved operator address; the empty address means no operator
//
// Returns:
//   - position: pointer to a position initialized with all supplied values
func NewPosition(
	poolKey string,
	tickLower int32,
	tickUpper int32,
	liquidity string,
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 string,
	tokensOwed0, tokensOwed1 int64,
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
		burned:                   burned,
		operator:                 operator,
	}
}

// NewPositionsTree allocates an empty BP-tree for position entries under the
// position realm context.
//
// Returns:
//   - positionsTree: empty position BP-tree allocated with fanout 16
func NewPositionsTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}
