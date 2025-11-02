// Simplified test implementation for position contract upgrade testing
package test

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/position"
)

func init() {
	position.RegisterInitializer(cross, func(store position.IPositionStore) position.IPosition {
		return &TestPosition{}
	})
}

// TestPosition is a minimal test implementation that panics on all methods
type TestPosition struct{}

// IPositionManager interface
func (t *TestPosition) Mint(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, caller address, referrer string) (uint64, string, string, string) {
	panic("test implementation: Mint not supported")
}

func (t *TestPosition) IncreaseLiquidity(positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	panic("test implementation: IncreaseLiquidity not supported")
}

func (t *TestPosition) DecreaseLiquidity(positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64, unwrapResult bool) (uint64, string, string, string, string, string, string) {
	panic("test implementation: DecreaseLiquidity not supported")
}

func (t *TestPosition) Reposition(positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string) (uint64, string, int32, int32, string, string) {
	panic("test implementation: Reposition not supported")
}

func (t *TestPosition) CollectFee(positionId uint64, unwrapResult bool) (uint64, string, string, string, string, string) {
	panic("test implementation: CollectFee not supported")
}

func (t *TestPosition) SetPositionOperator(positionId uint64, operator address) {
	panic("test implementation: SetPositionOperator not supported")
}

// IPositionGetter interface
func (t *TestPosition) GetPosition(positionId uint64) (position.Position, bool) {
	panic("test implementation: GetPosition not supported")
}

func (t *TestPosition) IsBurned(positionId uint64) bool {
	panic("test implementation: IsBurned not supported")
}

func (t *TestPosition) IsInRange(positionId uint64) bool {
	panic("test implementation: IsInRange not supported")
}

func (t *TestPosition) GetPositionOperator(positionId uint64) address {
	panic("test implementation: GetPositionOperator not supported")
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) string {
	panic("test implementation: GetPositionPoolKey not supported")
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) int32 {
	panic("test implementation: GetPositionTickLower not supported")
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) int32 {
	panic("test implementation: GetPositionTickUpper not supported")
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) *u256.Uint {
	panic("test implementation: GetPositionLiquidity not supported")
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	panic("test implementation: GetPositionFeeGrowthInside0LastX128 not supported")
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	panic("test implementation: GetPositionFeeGrowthInside1LastX128 not supported")
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	panic("test implementation: GetPositionTokensOwed0 not supported")
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	panic("test implementation: GetPositionTokensOwed1 not supported")
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	panic("test implementation: GetUnclaimedFee not supported")
}

func (t *TestPosition) GetPositionOwner(positionId uint64) address {
	panic("test implementation: GetPositionOwner not supported")
}

// IPositionApi interface
func (t *TestPosition) ApiGetPosition(positionId uint64) string {
	panic("test implementation: ApiGetPosition not supported")
}

func (t *TestPosition) ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string {
	panic("test implementation: ApiGetPositionUnclaimedFeeByPositionID not supported")
}
