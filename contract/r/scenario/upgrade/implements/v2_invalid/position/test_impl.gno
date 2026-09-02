// Simplified test implementation for position contract upgrade testing
package v2_invalid

import (
	"errors"

	"gno.land/r/gnoswap/access"

	grc721 "gno.land/p/demo/tokens/grc721"
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"

	gnft "gno.land/r/gnoswap/gnft"
	position "gno.land/r/gnoswap/position"
	v1 "gno.land/r/gnoswap/position/v1"
)

// NFTAccessor implementation for test
type gnftAccessor struct{}

func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return errors.New(position.ErrSpoofedRealm)
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	access.AssertIsRlmCurrent(0, rlm)

	return gnft.Mint(cross(rlm), to, tid)
}

func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	access.AssertIsRlmCurrent(0, rlm)

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

func NewV2InvalidPosition(store position.IPositionStore) position.IPosition {
	instance := v1.NewPositionV1(store, newGNFTAccessor())

	return &TestPosition{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init(cur realm) {
	position.RegisterInitializer(cross(cur), func(_ int, rlm realm, store position.IPositionStore) position.IPosition {
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
func (t *TestPosition) Mint(_ int, rlm realm, token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, referrer string) (uint64, string, string, string) {
	if !t.isActive("Mint") {
		panic("test implementation: Mint not supported")
	}
	return t.instance.Mint(0, rlm, token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, referrer)
}

func (t *TestPosition) IncreaseLiquidity(_ int, rlm realm, positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	if !t.isActive("IncreaseLiquidity") {
		panic("test implementation: IncreaseLiquidity not supported")
	}
	return t.instance.IncreaseLiquidity(0, rlm, positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) DecreaseLiquidity(_ int, rlm realm, positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string, string, string) {
	if !t.isActive("DecreaseLiquidity") {
		panic("test implementation: DecreaseLiquidity not supported")
	}
	return t.instance.DecreaseLiquidity(0, rlm, positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) Reposition(_ int, rlm realm, positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, int32, int32, string, string) {
	if !t.isActive("Reposition") {
		panic("test implementation: Reposition not supported")
	}
	return t.instance.Reposition(0, rlm, positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

func (t *TestPosition) CollectFee(_ int, rlm realm, positionId uint64) (uint64, string, string, string, string, string) {
	if !t.isActive("CollectFee") {
		panic("test implementation: CollectFee not supported")
	}
	return t.instance.CollectFee(0, rlm, positionId)
}

func (t *TestPosition) SetPositionOperator(_ int, rlm realm, positionId uint64, operator address) {
	if !t.isActive("SetPositionOperator") {
		panic("test implementation: SetPositionOperator not supported")
	}
	t.instance.SetPositionOperator(0, rlm, positionId, operator)
}

func (t *TestPosition) GetPositions() *rotree.ReadOnlyTree {
	if !t.isActive("GetPositions") {
		panic("test implementation: GetPositions not supported")
	}
	return t.instance.GetPositions()
}

func (t *TestPosition) IsBurned(positionId uint64) (bool, error) {
	if !t.isActive("IsBurned") {
		panic("test implementation: IsBurned not supported")
	}
	return t.instance.IsBurned(positionId)
}

func (t *TestPosition) IsInRange(positionId uint64) (bool, error) {
	if !t.isActive("IsInRange") {
		panic("test implementation: IsInRange not supported")
	}
	return t.instance.IsInRange(positionId)
}

func (t *TestPosition) GetPositionOperator(positionId uint64) (address, error) {
	if !t.isActive("GetPositionOperator") {
		panic("test implementation: GetPositionOperator not supported")
	}
	return t.instance.GetPositionOperator(positionId)
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) (string, error) {
	if !t.isActive("GetPositionPoolKey") {
		panic("test implementation: GetPositionPoolKey not supported")
	}
	return t.instance.GetPositionPoolKey(positionId)
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) (int32, error) {
	if !t.isActive("GetPositionTickLower") {
		panic("test implementation: GetPositionTickLower not supported")
	}
	return t.instance.GetPositionTickLower(positionId)
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) (int32, error) {
	if !t.isActive("GetPositionTickUpper") {
		panic("test implementation: GetPositionTickUpper not supported")
	}
	return t.instance.GetPositionTickUpper(positionId)
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) (string, error) {
	if !t.isActive("GetPositionLiquidity") {
		panic("test implementation: GetPositionLiquidity not supported")
	}
	return t.instance.GetPositionLiquidity(positionId)
}

func (t *TestPosition) GetPositionTokenBalances(positionId uint64) (int64, int64, error) {
	if !t.isActive("GetPositionTokenBalances") {
		panic("test implementation: GetPositionTokenBalances not supported")
	}
	return t.instance.GetPositionTokenBalances(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error) {
	if !t.isActive("GetPositionFeeGrowthInside0LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside0LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside0LastX128(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error) {
	if !t.isActive("GetPositionFeeGrowthInside1LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside1LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside1LastX128(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string, error) {
	if !t.isActive("GetPositionFeeGrowthInsideLastX128") {
		panic("test implementation: GetPositionFeeGrowthInsideLastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInsideLastX128(positionId)
}

func (t *TestPosition) GetPositionTicks(positionId uint64) (int32, int32, error) {
	if !t.isActive("GetPositionTicks") {
		panic("test implementation: GetPositionTicks not supported")
	}
	return t.instance.GetPositionTicks(positionId)
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) (int64, error) {
	if !t.isActive("GetPositionTokensOwed0") {
		panic("test implementation: GetPositionTokensOwed0 not supported")
	}
	return t.instance.GetPositionTokensOwed0(positionId)
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) (int64, error) {
	if !t.isActive("GetPositionTokensOwed1") {
		panic("test implementation: GetPositionTokensOwed1 not supported")
	}
	return t.instance.GetPositionTokensOwed1(positionId)
}

func (t *TestPosition) GetPositionTokensOwed(positionId uint64) (int64, int64, error) {
	if !t.isActive("GetPositionTokensOwed") {
		panic("test implementation: GetPositionTokensOwed not supported")
	}
	return t.instance.GetPositionTokensOwed(positionId)
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint, error) {
	if !t.isActive("GetUnclaimedFee") {
		panic("test implementation: GetUnclaimedFee not supported")
	}
	return t.instance.GetUnclaimedFee(positionId)
}

func (t *TestPosition) GetPositionOwner(positionId uint64) (address, error) {
	if !t.isActive("GetPositionOwner") {
		panic("test implementation: GetPositionOwner not supported")
	}
	return t.instance.GetPositionOwner(positionId)
}
