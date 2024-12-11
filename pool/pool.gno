package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Mint creates a new position and mints liquidity tokens.
// Returns minted amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#mint
func Mint(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	_liquidityAmount string,
	positionCaller std.Address,
) (string, string) {
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Mint() || only position(%s) can call pool mint(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)
	if liquidityAmount.IsZero() {
		panic(addDetailToError(
			errZeroLiquidity,
			ufmt.Sprintf("pool.gno__Mint() || liquidityAmount == 0"),
		))
	}

	pool := GetPool(token0Path, token1Path, fee)
	position := newModifyPositionParams(recipient, tickLower, tickUpper, i256.FromUint256(liquidityAmount))
	_, amount0, amount1 := pool.modifyPosition(position)

	if amount0.Gt(u256.Zero()) {
		pool.transferFromAndVerify(positionCaller, consts.POOL_ADDR, pool.token0Path, amount0, true)
	}

	if amount1.Gt(u256.Zero()) {
		pool.transferFromAndVerify(positionCaller, consts.POOL_ADDR, pool.token1Path, amount1, false)
	}

	return amount0.ToString(), amount1.ToString()
}

// Burn removes liquidity from the caller and account tokens owed for the liquidity to the position
// If liquidity of 0 is burned, it recalculates fees owed to a position
// Returns burned amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#burn
func Burn(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string, // uint128
) (string, string) { // uint256 x2
	common.IsHalted()
	caller := std.PrevRealm().Addr()
	if common.GetLimitCaller() {
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Burn() || only position(%s) can call pool burn(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liqAmount := u256.MustFromDecimal(liquidityAmount)

	pool := GetPool(token0Path, token1Path, fee)

	liqDelta := i256.Zero().Neg(i256.FromUint256(liqAmount))
	posParams := newModifyPositionParams(caller, tickLower, tickUpper, liqDelta)
	position, amount0, amount1 := pool.modifyPosition(posParams)

	if amount0.Gt(u256.Zero()) || amount1.Gt(u256.Zero()) {
		position.tokensOwed0 = new(u256.Uint).Add(position.tokensOwed0, amount0)
		position.tokensOwed1 = new(u256.Uint).Add(position.tokensOwed1, amount1)
	}

	positionKey := positionGetKey(caller, tickLower, tickUpper)
	pool.positions[positionKey] = position

	// actual token transfer happens in Collect()
	return amount0.ToString(), amount1.ToString()
}

// Collect collects tokens owed to a position
// Burned amounts, and swap fees will be transferred to the caller
// Returns collected amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#collect
func Collect(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	common.IsHalted()
	if common.GetLimitCaller() {
		caller := std.PrevRealm().Addr()
		if err := common.PositionOnly(caller); err != nil {
			panic(addDetailToError(
				errNoPermission,
				ufmt.Sprintf("pool.gno__Collect() || only position(%s) can call pool collect(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool.gno__Collect() || positionKey(%s) does not exist", positionKey),
		))
	}

	var amount0, amount1 *u256.Uint

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0, position.tokensOwed0, pool.balances.token0 = collectToken(amount0Req, position.tokensOwed0, pool.balances.token0)
	transferByRegisterCall(pool.token0Path, recipient, amount0.Uint64())

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1, position.tokensOwed1, pool.balances.token1 = collectToken(amount1Req, position.tokensOwed1, pool.balances.token1)
	transferByRegisterCall(pool.token1Path, recipient, amount1.Uint64())

	pool.positions[positionKey] = position

	return amount0.ToString(), amount1.ToString()
}

// collectToken handles the collection of a single token type (token0 or token1)
func collectToken(
	amountReq, tokensOwed, poolBalance *u256.Uint,
) (amount, newTokensOwed, newPoolBalance *u256.Uint) {
	// find smallest of three amounts
	amount = u256Min(amountReq, tokensOwed)
	amount = u256Min(amount, poolBalance)

	// value for update state
	newTokensOwed = new(u256.Uint).Sub(tokensOwed, amount)
	newPoolBalance = new(u256.Uint).Sub(poolBalance, amount)

	return amount, newTokensOwed, newPoolBalance
}

// SetFeeProtocolByAdmin sets the fee protocol for all pools
// Also it will be applied to new created pools
func SetFeeProtocolByAdmin(
	feeProtocol0 uint8,
	feeProtocol1 uint8,
) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	newFee := setFeeProtocol(feeProtocol0, feeProtocol1)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetFeeProtocolByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"feeProtocol0", ufmt.Sprintf("%d", feeProtocol0),
		"feeProtocol1", ufmt.Sprintf("%d", feeProtocol1),
		"internal_newFee", ufmt.Sprintf("%d", newFee),
	)
}

// SetFeeProtocol sets the fee protocol for all pools
// Only governance contract can execute this function via proposal
// Also it will be applied to new created pools
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#setfeeprotocol
func SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	newFee := setFeeProtocol(feeProtocol0, feeProtocol1)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetFeeProtocol",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"feeProtocol0", ufmt.Sprintf("%d", feeProtocol0),
		"feeProtocol1", ufmt.Sprintf("%d", feeProtocol1),
		"internal_newFee", ufmt.Sprintf("%d", newFee),
	)
}

func setFeeProtocol(feeProtocol0, feeProtocol1 uint8) uint8 {
	common.IsHalted()

	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		panic(addDetailToError(
			err,
			ufmt.Sprintf("pool.gno__setFeeProtocol() || expected (feeProtocol0(%d) == 0 || (feeProtocol0(%d) >= 4 && feeProtocol0(%d) <= 10)) && (feeProtocol1(%d) == 0 || (feeProtocol1(%d) >= 4 && feeProtocol1(%d) <= 10))", feeProtocol0, feeProtocol0, feeProtocol0, feeProtocol1, feeProtocol1, feeProtocol1),
		))
	}

	newFee := feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )

	// iterate all pool
	for _, pool := range pools {
		pool.slot0.feeProtocol = newFee
	}

	// update slot0
	slot0FeeProtocol = newFee

	return newFee
}

func validateFeeProtocol(feeProtocol0, feeProtocol1 uint8) error {
	if !isValidFeeProtocolValue(feeProtocol0) || !isValidFeeProtocolValue(feeProtocol1) {
		return errInvalidProtocolFeePct
	}
	return nil
}

func isValidFeeProtocolValue(value uint8) bool {
	return value == 0 || (value >= 4 && value <= 10)
}

// CollectProtocolByAdmin collects protocol fees for the given pool that accumulated while it was being used for swap
// Returns collected amount0, amount1 in string
func CollectProtocolByAdmin(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CollectProtocolByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", ufmt.Sprintf("%d", fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

// CollectProtocol collects protocol fees for the given pool that accumulated while it was being used for swap
// Only governance contract can execute this function via proposal
// Returns collected amount0, amount1 in string
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#collectprotocol
func CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	amount0, amount1 := collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CollectProtocol",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", ufmt.Sprintf("%d", fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

func collectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient std.Address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	common.IsHalted()

	pool := GetPool(token0Path, token1Path, fee)

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount1Req := u256.MustFromDecimal(amount1Requested)

	amount0 := u256Min(amount0Req, pool.protocolFees.token0)
	amount1 := u256Min(amount1Req, pool.protocolFees.token1)

	amount0, amount1 = pool.saveProtocolFees(amount0, amount1)
	uAmount0 := amount0.Uint64()
	uAmount1 := amount1.Uint64()

	transferByRegisterCall(pool.token0Path, recipient, uAmount0)
	transferByRegisterCall(pool.token1Path, recipient, uAmount1)

	return amount0.ToString(), amount1.ToString()
}

func (pool *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	cond01 := amount0.Gt(u256.Zero())
	cond02 := amount0.Eq(pool.protocolFees.token0)
	if cond01 && cond02 {
		amount0 = new(u256.Uint).Sub(amount0, u256.One())
	}

	cond11 := amount1.Gt(u256.Zero())
	cond12 := amount1.Eq(pool.protocolFees.token1)
	if cond11 && cond12 {
		amount1 = new(u256.Uint).Sub(amount1, u256.One())
	}

	pool.protocolFees.token0 = new(u256.Uint).Sub(pool.protocolFees.token0, amount0)
	pool.protocolFees.token1 = new(u256.Uint).Sub(pool.protocolFees.token1, amount1)

	// return rest fee
	return amount0, amount1
}

func (pool *Pool) transferAndVerify(
	to std.Address,
	tokenPath string,
	amount *i256.Int,
	isToken0 bool,
) {
	if amount.Sign() != -1 {
		panic(addDetailToError(
			errMustBeNegative,
			ufmt.Sprintf("pool.gno__transferAndVerify() || amount(%s) must be negative", amount.ToString()),
		))
	}

	absAmount := amount.Abs()

	token0 := pool.balances.token0
	token1 := pool.balances.token1

	if err := validatePoolBalance(token0, token1, absAmount, isToken0); err != nil {
		panic(err)
	}
	amountUint64, err := checkAmountRange(absAmount)
	if err != nil {
		panic(err)
	}

	transferByRegisterCall(tokenPath, to, amountUint64)

	newBalance, err := updatePoolBalance(token0, token1, absAmount, isToken0)
	if err != nil {
		panic(err)
	}

	if isToken0 {
		pool.balances.token0 = newBalance
	} else {
		pool.balances.token1 = newBalance
	}
}

func validatePoolBalance(token0, token1, amount *u256.Uint, isToken0 bool) error {
	if isToken0 {
		if token0.Lt(amount) {
			return ufmt.Errorf(
				"%s || token0(%s) >= amount(%s)",
				errTransferFailed.Error(), token0.ToString(), amount.ToString(),
			)
		}
		return nil
	}
	if token1.Lt(amount) {
		return ufmt.Errorf(
			"%s || token1(%s) >= amount(%s)",
			errTransferFailed.Error(), token1.ToString(), amount.ToString(),
		)
	}
	return nil
}

func updatePoolBalance(
	token0, token1, amount *u256.Uint,
	isToken0 bool,
) (*u256.Uint, error) {
	var overflow bool
	var newBalance *u256.Uint

	if isToken0 {
		newBalance, overflow = new(u256.Uint).SubOverflow(token0, amount)
		if isBalanceOverflowOrNegative(overflow, newBalance) {
			return nil, ufmt.Errorf(
				"%s || cannot decrease, token0(%s) - amount(%s)",
				errTransferFailed.Error(), token0.ToString(), amount.ToString(),
			)
		}
		return newBalance, nil
	}

	newBalance, overflow = new(u256.Uint).SubOverflow(token1, amount)
	if isBalanceOverflowOrNegative(overflow, newBalance) {
		return nil, ufmt.Errorf(
			"%s || cannot decrease, token1(%s) - amount(%s)",
			errTransferFailed.Error(), token1.ToString(), amount.ToString(),
		)
	}
	return newBalance, nil
}

func isBalanceOverflowOrNegative(overflow bool, newBalance *u256.Uint) bool {
	return overflow || newBalance.Lt(u256.Zero())
}

func (pool *Pool) transferFromAndVerify(
	from, to std.Address,
	tokenPath string,
	amount *u256.Uint,
	isToken0 bool,
) {
	absAmount := amount
	amountUint64, err := checkAmountRange(absAmount)
	if err != nil {
		panic(err)
	}

	// try sending
	// will panic if following conditions are met:
	// - POOL does not have enough approved amount
	// - from does not have enough balance
	// - token is not registered
	transferFromByRegisterCall(tokenPath, from, to, amountUint64)

	// update pool balances
	if isToken0 {
		pool.balances.token0 = new(u256.Uint).Add(pool.balances.token0, absAmount)
	} else {
		pool.balances.token1 = new(u256.Uint).Add(pool.balances.token1, absAmount)
	}
}

func checkAmountRange(amount *u256.Uint) (uint64, error) {
	res, overflow := amount.Uint64WithOverflow()
	if overflow {
		return 0, ufmt.Errorf(
			"%s || amount(%s) overflows uint64 range",
			errOutOfRange.Error(), amount.ToString(),
		)
	}

	return res, nil
}

// receiver getters
func (p *Pool) PoolGetToken0Path() string {
	return p.token0Path
}

func (p *Pool) PoolGetToken1Path() string {
	return p.token1Path
}

func (p *Pool) PoolGetFee() uint32 {
	return p.fee
}

func (p *Pool) PoolGetBalanceToken0() *u256.Uint {
	return p.balances.token0
}

func (p *Pool) PoolGetBalanceToken1() *u256.Uint {
	return p.balances.token1
}

func (p *Pool) PoolGetTickSpacing() int32 {
	return p.tickSpacing
}

func (p *Pool) PoolGetMaxLiquidityPerTick() *u256.Uint {
	return p.maxLiquidityPerTick
}

func (p *Pool) PoolGetSlot0() Slot0 {
	return p.slot0
}

func (p *Pool) PoolGetSlot0SqrtPriceX96() *u256.Uint {
	return p.slot0.sqrtPriceX96
}

func (p *Pool) PoolGetSlot0Tick() int32 {
	return p.slot0.tick
}

func (p *Pool) PoolGetSlot0FeeProtocol() uint8 {
	return p.slot0.feeProtocol
}

func (p *Pool) PoolGetSlot0Unlocked() bool {
	return p.slot0.unlocked
}

func (p *Pool) PoolGetFeeGrowthGlobal0X128() *u256.Uint {
	return p.feeGrowthGlobal0X128
}

func (p *Pool) PoolGetFeeGrowthGlobal1X128() *u256.Uint {
	return p.feeGrowthGlobal1X128
}

func (p *Pool) PoolGetProtocolFeesToken0() *u256.Uint {
	return p.protocolFees.token0
}

func (p *Pool) PoolGetProtocolFeesToken1() *u256.Uint {
	return p.protocolFees.token1
}

func (p *Pool) PoolGetLiquidity() *u256.Uint {
	return p.liquidity
}

func mustGetPool(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(errDataNotFound,
			ufmt.Sprintf("poolPath(%s) does not exist", poolPath)))
	}
	return pool
}
