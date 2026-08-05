// Simplified test implementation for position contract upgrade testing
package mock

import (
	"errors"

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
		return errors.New(position.ErrSpoofedRealm)
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
	instance := v1.NewPositionV1(store, newGNFTAccessor())

	return &TestPosition{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
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
	mockFns  map[string]func(args ...any) any
}

func (t *TestPosition) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestPosition) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IPositionManager interface
func (t *TestPosition) Mint(_ int, rlm realm, token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, referrer string) (uint64, string, string, string) {
	result := t.ExecuteFn(
		"Mint",
		func(args ...any) any {
			r1, r2, r3, r4 := t.instance.Mint(0, rlm, args[0].(string), args[1].(string), args[2].(uint32), args[3].(int32), args[4].(int32), args[5].(string), args[6].(string), args[7].(string), args[8].(string), args[9].(int64), args[10].(address), args[11].(string))
			return []any{r1, r2, r3, r4}
		},
		token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, referrer,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string)
}

func (t *TestPosition) IncreaseLiquidity(_ int, rlm realm, positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	result := t.ExecuteFn(
		"IncreaseLiquidity",
		func(args ...any) any {
			r1, r2, r3, r4, r5 := t.instance.IncreaseLiquidity(0, rlm, args[0].(uint64), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(int64))
			return []any{r1, r2, r3, r4, r5}
		},
		positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string)
}

func (t *TestPosition) DecreaseLiquidity(_ int, rlm realm, positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string, string, string) {
	result := t.ExecuteFn(
		"DecreaseLiquidity",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6, r7 := t.instance.DecreaseLiquidity(0, rlm, args[0].(uint64), args[1].(string), args[2].(string), args[3].(string), args[4].(int64))
			return []any{r1, r2, r3, r4, r5, r6, r7}
		},
		positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string), result[5].(string), result[6].(string)
}

func (t *TestPosition) Reposition(_ int, rlm realm, positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, int32, int32, string, string) {
	result := t.ExecuteFn(
		"Reposition",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6 := t.instance.Reposition(0, rlm, args[0].(uint64), args[1].(int32), args[2].(int32), args[3].(string), args[4].(string), args[5].(string), args[6].(string), args[7].(int64))
			return []any{r1, r2, r3, r4, r5, r6}
		},
		positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(int32), result[3].(int32), result[4].(string), result[5].(string)
}

func (t *TestPosition) CollectFee(_ int, rlm realm, positionId uint64) (uint64, string, string, string, string, string) {
	result := t.ExecuteFn(
		"CollectFee",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6 := t.instance.CollectFee(0, rlm, args[0].(uint64))
			return []any{r1, r2, r3, r4, r5, r6}
		},
		positionId,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string), result[5].(string)
}

func (t *TestPosition) SetPositionOperator(_ int, rlm realm, positionId uint64, operator address) {
	t.ExecuteFn(
		"SetPositionOperator",
		func(args ...any) any {
			t.instance.SetPositionOperator(0, rlm, args[0].(uint64), args[1].(address))
			return nil
		},
		positionId, operator,
	)
}

// IPositionGetter interface
func (t *TestPosition) GetPositionCount() int {
	return t.ExecuteFn(
		"GetPositionCount",
		func(args ...any) any { return t.instance.GetPositionCount() },
	).(int)
}

func (t *TestPosition) GetPositionIDs(offset, count int) []uint64 {
	return t.ExecuteFn(
		"GetPositionIDs",
		func(args ...any) any { return t.instance.GetPositionIDs(args[0].(int), args[1].(int)) },
		offset, count,
	).([]uint64)
}

func (t *TestPosition) GetPosition(positionId uint64) (position.Position, bool) {
	result := t.ExecuteFn(
		"GetPosition",
		func(args ...any) any {
			r1, r2 := t.instance.GetPosition(args[0].(uint64))
			return []any{r1, r2}
		},
		positionId,
	).([]any)
	return result[0].(position.Position), result[1].(bool)
}

func (t *TestPosition) IsBurned(positionId uint64) (bool, error) {
	return t.instance.IsBurned(positionId)
}

func (t *TestPosition) IsInRange(positionId uint64) (bool, error) {
	return t.instance.IsInRange(positionId)
}

func (t *TestPosition) GetPositionOperator(positionId uint64) (address, error) {
	return t.instance.GetPositionOperator(positionId)
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) (string, error) {
	return t.instance.GetPositionPoolKey(positionId)
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) (int32, error) {
	return t.instance.GetPositionTickLower(positionId)
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) (int32, error) {
	return t.instance.GetPositionTickUpper(positionId)
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) (string, error) {
	return t.instance.GetPositionLiquidity(positionId)
}

func (t *TestPosition) GetPositionTokenBalances(positionId uint64) (int64, int64, error) {
	return t.instance.GetPositionTokenBalances(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error) {
	return t.instance.GetPositionFeeGrowthInside0LastX128(positionId)
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error) {
	return t.instance.GetPositionFeeGrowthInside1LastX128(positionId)
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) (int64, error) {
	return t.instance.GetPositionTokensOwed0(positionId)
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) (int64, error) {
	return t.instance.GetPositionTokensOwed1(positionId)
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint, error) {
	return t.instance.GetUnclaimedFee(positionId)
}

func (t *TestPosition) GetPositionOwner(positionId uint64) (address, error) {
	return t.instance.GetPositionOwner(positionId)
}
