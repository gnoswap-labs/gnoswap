package impl

import (
	"chain/runtime"

	position "gno.land/r/gnoswap/v1/position"
)

// PositionImpl wraps the v1 position contract to implement the Position interface.
// This allows the position to be used with the upgradeable proxy pattern.
type PositionImpl struct{}

var positionImpl *PositionImpl = &PositionImpl{}
var gRealm = runtime.CurrentRealm()

// GetInstance returns the position implementation instance.
// Only accessible from the loader package.
func GetInstance() *PositionImpl {
	caller := runtime.PreviousRealm().PkgPath()
	if caller != "gno.land/r/gnoswap/v1/position/loader" {
		panic("not allowed: only loader can get instance")
	}

	return positionImpl
}

// Mint creates a new liquidity position NFT.
func (p *PositionImpl) Mint(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	mintTo address,
	caller address,
	referrer string,
) (uint64, string, string, string) {
	return position.Mint(cross, token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, caller, referrer)
}

// IncreaseLiquidity increases liquidity of an existing position.
func (p *PositionImpl) IncreaseLiquidity(
	cur realm,
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	return position.IncreaseLiquidity(cross, positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

// DecreaseLiquidity decreases liquidity of an existing position.
func (p *PositionImpl) DecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	return position.DecreaseLiquidity(cross, positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline, unwrapResult)
}

// CollectFee collects swap fee from the position.
func (p *PositionImpl) CollectFee(
	cur realm,
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	return position.CollectFee(cross, positionId, unwrapResult)
}

// SetPositionOperator sets an operator for a position.
func (p *PositionImpl) SetPositionOperator(
	cur realm,
	id uint64,
	operator address,
) {
	position.SetPositionOperator(cross, id, operator)
}

// Reposition creates a new position with liquidity from an existing position.
func (p *PositionImpl) Reposition(
	cur realm,
	tokenId uint64,
	targetTokenId uint64,
	removeRatio uint64,
	amount0Min string,
	amount1Min string,
	swapDirection string,
	swapAmount string,
	swapAmountMin string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string) {
	return position.Reposition(cross, tokenId, targetTokenId, removeRatio, amount0Min, amount1Min, swapDirection, swapAmount, swapAmountMin, deadline, unwrapResult)
}

// GetNextPositionId returns the next position ID to be minted.
func (p *PositionImpl) GetNextPositionId() uint64 {
	return position.GetNextPositionId()
}

// PositionGetPositionLiquidityStr returns liquidity as string for a position.
func (p *PositionImpl) PositionGetPositionLiquidityStr(positionId uint64) string {
	return position.PositionGetPositionLiquidityStr(positionId)
}

// PositionGetPositionOperator returns operator address for a position.
func (p *PositionImpl) PositionGetPositionOperator(positionId uint64) address {
	return position.PositionGetPositionOperator(positionId)
}

// PositionGetPositionPoolKey returns pool key for a position.
func (p *PositionImpl) PositionGetPositionPoolKey(positionId uint64) string {
	return position.PositionGetPositionPoolKey(positionId)
}

// PositionGetPositionTickLower returns tick lower for a position.
func (p *PositionImpl) PositionGetPositionTickLower(positionId uint64) int32 {
	return position.PositionGetPositionTickLower(positionId)
}

// PositionGetPositionTickUpper returns tick upper for a position.
func (p *PositionImpl) PositionGetPositionTickUpper(positionId uint64) int32 {
	return position.PositionGetPositionTickUpper(positionId)
}

// PositionGetPositionOwner returns owner address for a position.
func (p *PositionImpl) PositionGetPositionOwner(positionId uint64) address {
	return position.PositionGetPositionOwner(positionId)
}

// PositionIsInRange checks if position is in range.
func (p *PositionImpl) PositionIsInRange(positionId uint64) bool {
	return position.PositionIsInRange(positionId)
}

// ApiGetPosition returns position data as JSON.
func (p *PositionImpl) ApiGetPosition(positionId uint64) string {
	return position.ApiGetPosition(positionId)
}

// ApiGetPositions returns all positions as JSON.
func (p *PositionImpl) ApiGetPositions() string {
	return position.ApiGetPositions()
}

// MustGetPosition returns position or panics if not found.
// Note: This returns the actual Position struct from the position package, not the interface.
func (p *PositionImpl) MustGetPosition(positionId uint64) position.Position {
	return position.MustGetPosition(positionId)
}
