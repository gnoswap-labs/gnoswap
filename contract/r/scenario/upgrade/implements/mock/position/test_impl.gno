// Simplified test implementation for position contract upgrade testing
package mock

import (
	"gno.land/p/demo/tokens/grc721"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/position/v1"
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

func NewV3ValidPosition(store position.IPositionStore) position.IPosition {
	instance := v1.NewPositionV1(store, newGNFTAccessor())

	return &TestPosition{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
	}
}

func init() {
	position.RegisterInitializer(cross, func(store position.IPositionStore) position.IPosition {
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
func (t *TestPosition) Mint(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, caller address, referrer string) (uint64, string, string, string) {
	result := t.ExecuteFn(
		"Mint",
		func(args ...any) any {
			r1, r2, r3, r4 := t.instance.Mint(args[0].(string), args[1].(string), args[2].(uint32), args[3].(int32), args[4].(int32), args[5].(string), args[6].(string), args[7].(string), args[8].(string), args[9].(int64), args[10].(address), args[11].(address), args[12].(string))
			return []any{r1, r2, r3, r4}
		},
		token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, caller, referrer,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string)
}

func (t *TestPosition) IncreaseLiquidity(positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string) {
	result := t.ExecuteFn(
		"IncreaseLiquidity",
		func(args ...any) any {
			r1, r2, r3, r4, r5 := t.instance.IncreaseLiquidity(args[0].(uint64), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(int64))
			return []any{r1, r2, r3, r4, r5}
		},
		positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string)
}

func (t *TestPosition) DecreaseLiquidity(positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64, unwrapResult bool) (uint64, string, string, string, string, string, string) {
	result := t.ExecuteFn(
		"DecreaseLiquidity",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6, r7 := t.instance.DecreaseLiquidity(args[0].(uint64), args[1].(string), args[2].(string), args[3].(string), args[4].(int64), args[5].(bool))
			return []any{r1, r2, r3, r4, r5, r6, r7}
		},
		positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline, unwrapResult,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string), result[5].(string), result[6].(string)
}

func (t *TestPosition) Reposition(positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string) (uint64, string, int32, int32, string, string) {
	result := t.ExecuteFn(
		"Reposition",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6 := t.instance.Reposition(args[0].(uint64), args[1].(int32), args[2].(int32), args[3].(string), args[4].(string), args[5].(string), args[6].(string))
			return []any{r1, r2, r3, r4, r5, r6}
		},
		positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(int32), result[3].(int32), result[4].(string), result[5].(string)
}

func (t *TestPosition) CollectFee(positionId uint64, unwrapResult bool) (uint64, string, string, string, string, string) {
	result := t.ExecuteFn(
		"CollectFee",
		func(args ...any) any {
			r1, r2, r3, r4, r5, r6 := t.instance.CollectFee(args[0].(uint64), args[1].(bool))
			return []any{r1, r2, r3, r4, r5, r6}
		},
		positionId, unwrapResult,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string), result[5].(string)
}

func (t *TestPosition) SetPositionOperator(positionId uint64, operator address) {
	t.ExecuteFn(
		"SetPositionOperator",
		func(args ...any) any { t.instance.SetPositionOperator(args[0].(uint64), args[1].(address)); return nil },
		positionId, operator,
	)
}

// IPositionGetter interface
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

func (t *TestPosition) IsBurned(positionId uint64) bool {
	return t.ExecuteFn(
		"IsBurned",
		func(args ...any) any { return t.instance.IsBurned(args[0].(uint64)) },
		positionId,
	).(bool)
}

func (t *TestPosition) IsInRange(positionId uint64) bool {
	return t.ExecuteFn(
		"IsInRange",
		func(args ...any) any { return t.instance.IsInRange(args[0].(uint64)) },
		positionId,
	).(bool)
}

func (t *TestPosition) GetPositionOperator(positionId uint64) address {
	return t.ExecuteFn(
		"GetPositionOperator",
		func(args ...any) any { return t.instance.GetPositionOperator(args[0].(uint64)) },
		positionId,
	).(address)
}

func (t *TestPosition) GetPositionPoolKey(positionId uint64) string {
	return t.ExecuteFn(
		"GetPositionPoolKey",
		func(args ...any) any { return t.instance.GetPositionPoolKey(args[0].(uint64)) },
		positionId,
	).(string)
}

func (t *TestPosition) GetPositionTickLower(positionId uint64) int32 {
	return t.ExecuteFn(
		"GetPositionTickLower",
		func(args ...any) any { return t.instance.GetPositionTickLower(args[0].(uint64)) },
		positionId,
	).(int32)
}

func (t *TestPosition) GetPositionTickUpper(positionId uint64) int32 {
	return t.ExecuteFn(
		"GetPositionTickUpper",
		func(args ...any) any { return t.instance.GetPositionTickUpper(args[0].(uint64)) },
		positionId,
	).(int32)
}

func (t *TestPosition) GetPositionLiquidity(positionId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionLiquidity",
		func(args ...any) any { return t.instance.GetPositionLiquidity(args[0].(uint64)) },
		positionId,
	).(*u256.Uint)
}

func (t *TestPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionFeeGrowthInside0LastX128",
		func(args ...any) any { return t.instance.GetPositionFeeGrowthInside0LastX128(args[0].(uint64)) },
		positionId,
	).(*u256.Uint)
}

func (t *TestPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionFeeGrowthInside1LastX128",
		func(args ...any) any { return t.instance.GetPositionFeeGrowthInside1LastX128(args[0].(uint64)) },
		positionId,
	).(*u256.Uint)
}

func (t *TestPosition) GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionTokensOwed0",
		func(args ...any) any { return t.instance.GetPositionTokensOwed0(args[0].(uint64)) },
		positionId,
	).(*u256.Uint)
}

func (t *TestPosition) GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionTokensOwed1",
		func(args ...any) any { return t.instance.GetPositionTokensOwed1(args[0].(uint64)) },
		positionId,
	).(*u256.Uint)
}

func (t *TestPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	result := t.ExecuteFn(
		"GetUnclaimedFee",
		func(args ...any) any {
			r1, r2 := t.instance.GetUnclaimedFee(args[0].(uint64))
			return []any{r1, r2}
		},
		positionId,
	).([]any)
	return result[0].(*u256.Uint), result[1].(*u256.Uint)
}

func (t *TestPosition) GetPositionOwner(positionId uint64) address {
	return t.ExecuteFn(
		"GetPositionOwner",
		func(args ...any) any { return t.instance.GetPositionOwner(args[0].(uint64)) },
		positionId,
	).(address)
}

// IPositionApi interface
func (t *TestPosition) ApiGetPosition(positionId uint64) string {
	return t.ExecuteFn(
		"ApiGetPosition",
		func(args ...any) any { return t.instance.ApiGetPosition(args[0].(uint64)) },
		positionId,
	).(string)
}

func (t *TestPosition) ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string {
	return t.ExecuteFn(
		"ApiGetPositionUnclaimedFeeByPositionID",
		func(args ...any) any { return t.instance.ApiGetPositionUnclaimedFeeByPositionID(args[0].(uint64)) },
		positionId,
	).(string)
}
