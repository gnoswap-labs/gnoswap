package position

import (
	"chain/runtime"
)

// position is the actual position implementation, having all the needed business logic.
var position Position

// allowedImpls contains realms that can be used to update the actual position implementation.
// This is like that to be able to rollback using a previous position implementation in case
// the latest implementation has a breaking bug. After a test period, a proposal can be
// executed to remove all previous position implementations and leave the last one.
var allowedImpls []string

// Mint proxies to the current position implementation.
func Mint(
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

// IncreaseLiquidity proxies to the current position implementation.
func IncreaseLiquidity(
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

// DecreaseLiquidity proxies to the current position implementation.
func DecreaseLiquidity(
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

// CollectFee proxies to the current position implementation.
func CollectFee(
	cur realm,
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	return position.CollectFee(cross, positionId, unwrapResult)
}

// SetPositionOperator proxies to the current position implementation.
func SetPositionOperator(
	cur realm,
	id uint64,
	operator address,
) {
	position.SetPositionOperator(cross, id, operator)
}

// Reposition proxies to the current position implementation.
func Reposition(
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

// GetNextPositionId proxies to the current position implementation.
func GetNextPositionId() uint64 {
	return position.GetNextPositionId()
}

// PositionGetPositionLiquidityStr proxies to the current position implementation.
func PositionGetPositionLiquidityStr(positionId uint64) string {
	return position.PositionGetPositionLiquidityStr(positionId)
}

// PositionGetPositionOperator proxies to the current position implementation.
func PositionGetPositionOperator(positionId uint64) address {
	return position.PositionGetPositionOperator(positionId)
}

// PositionGetPositionPoolKey proxies to the current position implementation.
func PositionGetPositionPoolKey(positionId uint64) string {
	return position.PositionGetPositionPoolKey(positionId)
}

// PositionGetPositionTickLower proxies to the current position implementation.
func PositionGetPositionTickLower(positionId uint64) int32 {
	return position.PositionGetPositionTickLower(positionId)
}

// PositionGetPositionTickUpper proxies to the current position implementation.
func PositionGetPositionTickUpper(positionId uint64) int32 {
	return position.PositionGetPositionTickUpper(positionId)
}

// PositionGetPositionOwner proxies to the current position implementation.
func PositionGetPositionOwner(positionId uint64) address {
	return position.PositionGetPositionOwner(positionId)
}

// PositionIsInRange proxies to the current position implementation.
func PositionIsInRange(positionId uint64) bool {
	return position.PositionIsInRange(positionId)
}

// ApiGetPosition proxies to the current position implementation.
func ApiGetPosition(positionId uint64) string {
	return position.ApiGetPosition(positionId)
}

// ApiGetPositions proxies to the current position implementation.
func ApiGetPositions() string {
	return position.ApiGetPositions()
}

// UpdateImpl updates the current position implementation.
// This method is intended to be used on a proposal or by admin.
// AllowedImpls are a list of realms that can call this method,
// in case the new position implementation had a breaking bug.
// Any value set as nil will be ignored.
func UpdateImpl(cur realm, r UpdateRequest) {
	gRealm := runtime.PreviousRealm().PkgPath()

	if !InAllowedImpls(gRealm) {
		panic("permission denied for prev realm: " + gRealm)
	}

	if r.AllowedImpls != nil {
		allowedImpls = r.AllowedImpls
	}

	if r.Position != nil {
		position = r.Position
	}
}

// AllowedImpls returns a copy of the allowed implementations list.
func AllowedImpls() []string {
	dup := make([]string, len(allowedImpls))
	copy(dup, allowedImpls)
	return dup
}

// InAllowedImpls checks if a package is in the allowed implementations list.
func InAllowedImpls(pkg string) bool {
	if len(allowedImpls) == 0 {
		return true // corner case for initialization
	}
	for _, d := range allowedImpls {
		if pkg == d {
			return true
		}
	}
	return false
}
