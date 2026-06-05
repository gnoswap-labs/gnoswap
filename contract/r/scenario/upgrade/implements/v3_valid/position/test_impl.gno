// Simplified test implementation for position contract upgrade testing
package v3_valid

import (
	"gno.land/p/demo/tokens/grc721"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/position"
	v1 "gno.land/r/gnoswap/position/v1"
)

// NFTAccessor implementation for test
type gnftAccessor struct{}

func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return position.ErrSpoofedRealm
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	if !rlm.IsCurrent() {
		panic(position.ErrSpoofedRealm)
	}

	return gnft.Mint(cross(rlm), to, tid)
}

func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	if !rlm.IsCurrent() {
		panic(position.ErrSpoofedRealm)
	}

	gnft.Burn(cross(rlm), tid)
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

func NewV3ValidPosition(store position.IPositionStore) position.IPosition {
	return &TestPosition{
		instance: v1.NewPositionV1(store, newGNFTAccessor()),
	}
}

func init(cur realm) {
	position.RegisterInitializer(cross(cur), func(_ int, rlm realm, store position.IPositionStore) position.IPosition {
		return NewV3ValidPosition(store)
	})
}

// TestPosition is a minimal test implementation that delegates to v1
type TestPosition struct {
	instance position.IPosition
}

// IPositionManager interface
func (t *TestPosition) Mint(_ int, rlm realm, token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, referrer string) (uint64, string, string, string) {
	return t.instance.Mint(0, rlm, token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, referrer)
}

func (t *TestPosition) IncreaseLiquidity(_ int, rlm realm, positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	return t.instance.IncreaseLiquidity(0, rlm, positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) DecreaseLiquidity(_ int, rlm realm, positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string, string, string) {
	return t.instance.DecreaseLiquidity(0, rlm, positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) Reposition(_ int, rlm realm, positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, int32, int32, string, string) {
	return t.instance.Reposition(0, rlm, positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) CollectFee(_ int, rlm realm, positionId uint64) (uint64, string, string, string, string, string) {
	return t.instance.CollectFee(0, rlm, positionId)
}

func (t *TestPosition) SetPositionOperator(_ int, rlm realm, positionId uint64, operator address) {
	t.instance.SetPositionOperator(0, rlm, positionId, operator)
}

// IPositionGetter interface
func (t *TestPosition) GetPositionCount() int {
	return t.instance.GetPositionCount()
}

func (t *TestPosition) GetPositionIDs(offset, count int) []uint64 {
	return t.instance.GetPositionIDs(offset, count)
}

func (t *TestPosition) GetPosition(positionId uint64) (position.Position, bool) {
	return t.instance.GetPosition(positionId)
}

func (t *TestPosition) IsBurned(positionId uint64) bool {
	return t.instance.IsBurned(positionId)
}

func (t *TestPosition) IsInRange(positionId uint64) bool {
	return t.instance.IsInRange(positionId)
}

func (t *TestPosition) GetPositionOperator(positionId uint64) address {
	return t.instance.GetPositionOperator(positionId)
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) string {
	return t.instance.GetPositionPoolKey(positionId)
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) int32 {
	return t.instance.GetPositionTickLower(positionId)
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) int32 {
	return t.instance.GetPositionTickUpper(positionId)
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) string {
	return t.instance.GetPositionLiquidity(positionId)
}

func (t *TestPosition) GetPositionTokenBalances(positionId uint64) (int64, int64) {
	return t.instance.GetPositionTokenBalances(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) string {
	return t.instance.GetPositionFeeGrowthInside0LastX128(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) string {
	return t.instance.GetPositionFeeGrowthInside1LastX128(positionId)
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) int64 {
	return t.instance.GetPositionTokensOwed0(positionId)
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) int64 {
	return t.instance.GetPositionTokensOwed1(positionId)
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	return t.instance.GetUnclaimedFee(positionId)
}

func (t *TestPosition) GetPositionOwner(positionId uint64) address {
	return t.instance.GetPositionOwner(positionId)
}
