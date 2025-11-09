// Simplified test implementation for position contract upgrade testing
package v2_invalid

import (
	grc721 "gno.land/p/demo/tokens/grc721"
	u256 "gno.land/p/gnoswap/uint256"
	gnft "gno.land/r/gnoswap/gnft"
	position "gno.land/r/gnoswap/position"
	v1 "gno.land/r/gnoswap/position/v1"
)

// NFTAccessor implementation for test
type gnftAccessor struct{}

func (n *gnftAccessor) Approve(approved address, tid grc721.TokenID) error {
	return gnft.Approve(cross, approved, tid)
}

func (n *gnftAccessor) Mint(to address, tid grc721.TokenID) grc721.TokenID {
	return gnft.Mint(cross, to, tid)
}

func (n *gnftAccessor) Burn(tid grc721.TokenID) {
	gnft.Burn(cross, tid)
}

func (n *gnftAccessor) TotalSupply() int64 {
	return gnft.TotalSupply()
}

func (n *gnftAccessor) Exists(tid grc721.TokenID) bool {
	return gnft.Exists(tid)
}

func (n *gnftAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	return gnft.OwnerOf(tid)
}

func newGNFTAccessor() v1.NFTAccessor {
	return &gnftAccessor{}
}

func NewV2InvalidPosition(store position.IPositionStore) position.IPosition {
	instance := v1.NewPositionV1(store, newGNFTAccessor())

	return &TestPosition{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	position.RegisterInitializer(cross, func(store position.IPositionStore) position.IPosition {
		return NewV2InvalidPosition(store)
	})
}

// TestPosition is a minimal test implementation that delegates to v1 only when method is activated
type TestPosition struct {
	instance      position.IPosition
	activeMethods map[string]bool
}

func (t *TestPosition) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestPosition) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IPositionManager interface
func (t *TestPosition) Mint(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, caller address, referrer string) (uint64, string, string, string) {
	if !t.isActive("Mint") {
		panic("test implementation: Mint not supported")
	}
	return t.instance.Mint(token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, caller, referrer)
}

func (t *TestPosition) IncreaseLiquidity(positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	if !t.isActive("IncreaseLiquidity") {
		panic("test implementation: IncreaseLiquidity not supported")
	}
	return t.instance.IncreaseLiquidity(positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) DecreaseLiquidity(positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64, unwrapResult bool) (uint64, string, string, string, string, string, string) {
	if !t.isActive("DecreaseLiquidity") {
		panic("test implementation: DecreaseLiquidity not supported")
	}
	return t.instance.DecreaseLiquidity(positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline, unwrapResult)
}

func (t *TestPosition) Reposition(positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string) (uint64, string, int32, int32, string, string) {
	if !t.isActive("Reposition") {
		panic("test implementation: Reposition not supported")
	}
	return t.instance.Reposition(positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr)
}

func (t *TestPosition) CollectFee(positionId uint64, unwrapResult bool) (uint64, string, string, string, string, string) {
	if !t.isActive("CollectFee") {
		panic("test implementation: CollectFee not supported")
	}
	return t.instance.CollectFee(positionId, unwrapResult)
}

func (t *TestPosition) SetPositionOperator(positionId uint64, operator address) {
	if !t.isActive("SetPositionOperator") {
		panic("test implementation: SetPositionOperator not supported")
	}
	t.instance.SetPositionOperator(positionId, operator)
}

// IPositionGetter interface
func (t *TestPosition) GetPosition(positionId uint64) (position.Position, bool) {
	if !t.isActive("GetPosition") {
		panic("test implementation: GetPosition not supported")
	}
	return t.instance.GetPosition(positionId)
}

func (t *TestPosition) IsBurned(positionId uint64) bool {
	if !t.isActive("IsBurned") {
		panic("test implementation: IsBurned not supported")
	}
	return t.instance.IsBurned(positionId)
}

func (t *TestPosition) IsInRange(positionId uint64) bool {
	if !t.isActive("IsInRange") {
		panic("test implementation: IsInRange not supported")
	}
	return t.instance.IsInRange(positionId)
}

func (t *TestPosition) GetPositionOperator(positionId uint64) address {
	if !t.isActive("GetPositionOperator") {
		panic("test implementation: GetPositionOperator not supported")
	}
	return t.instance.GetPositionOperator(positionId)
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) string {
	if !t.isActive("GetPositionPoolKey") {
		panic("test implementation: GetPositionPoolKey not supported")
	}
	return t.instance.GetPositionPoolKey(positionId)
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) int32 {
	if !t.isActive("GetPositionTickLower") {
		panic("test implementation: GetPositionTickLower not supported")
	}
	return t.instance.GetPositionTickLower(positionId)
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) int32 {
	if !t.isActive("GetPositionTickUpper") {
		panic("test implementation: GetPositionTickUpper not supported")
	}
	return t.instance.GetPositionTickUpper(positionId)
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) *u256.Uint {
	if !t.isActive("GetPositionLiquidity") {
		panic("test implementation: GetPositionLiquidity not supported")
	}
	return t.instance.GetPositionLiquidity(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	if !t.isActive("GetPositionFeeGrowthInside0LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside0LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside0LastX128(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	if !t.isActive("GetPositionFeeGrowthInside1LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside1LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside1LastX128(positionId)
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	if !t.isActive("GetPositionTokensOwed0") {
		panic("test implementation: GetPositionTokensOwed0 not supported")
	}
	return t.instance.GetPositionTokensOwed0(positionId)
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	if !t.isActive("GetPositionTokensOwed1") {
		panic("test implementation: GetPositionTokensOwed1 not supported")
	}
	return t.instance.GetPositionTokensOwed1(positionId)
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	if !t.isActive("GetUnclaimedFee") {
		panic("test implementation: GetUnclaimedFee not supported")
	}
	return t.instance.GetUnclaimedFee(positionId)
}

func (t *TestPosition) GetPositionOwner(positionId uint64) address {
	if !t.isActive("GetPositionOwner") {
		panic("test implementation: GetPositionOwner not supported")
	}
	return t.instance.GetPositionOwner(positionId)
}

// IPositionApi interface
func (t *TestPosition) ApiGetPosition(positionId uint64) string {
	if !t.isActive("ApiGetPosition") {
		panic("test implementation: ApiGetPosition not supported")
	}
	return t.instance.ApiGetPosition(positionId)
}

func (t *TestPosition) ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string {
	if !t.isActive("ApiGetPositionUnclaimedFeeByPositionID") {
		panic("test implementation: ApiGetPositionUnclaimedFeeByPositionID not supported")
	}
	return t.instance.ApiGetPositionUnclaimedFeeByPositionID(positionId)
}
