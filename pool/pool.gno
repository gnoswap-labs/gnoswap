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
				ufmt.Sprintf("only position(%s) can call pool mint(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	liquidityAmount := u256.MustFromDecimal(_liquidityAmount)
	if liquidityAmount.IsZero() {
		panic(errZeroLiquidity)
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
				ufmt.Sprintf("only position(%s) can call pool burn(), called from %s", consts.POSITION_ADDR, caller.String()),
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
				ufmt.Sprintf("only position(%s) can call pool collect(), called from %s", consts.POSITION_ADDR, caller.String()),
			))
		}
	}

	pool := GetPool(token0Path, token1Path, fee)

	positionKey := positionGetKey(std.PrevRealm().Addr(), tickLower, tickUpper)
	position, exist := pool.positions[positionKey]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("positionKey(%s) does not exist", positionKey),
		))
	}

	var amount0, amount1 *u256.Uint

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0, position.tokensOwed0, pool.balances.token0 = collectToken(amount0Req, position.tokensOwed0, pool.balances.token0)
	token0 := common.GetTokenTeller(pool.token0Path)
	checkTransferError(token0.Transfer(recipient, amount0.Uint64()))

	// Smallest of three: amount0Requested, position.tokensOwed0, pool.balances.token0
	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1, position.tokensOwed1, pool.balances.token1 = collectToken(amount1Req, position.tokensOwed1, pool.balances.token1)

	// Update state first then transfer
	position.tokensOwed1 = new(u256.Uint).Sub(position.tokensOwed1, amount1)
	pool.balances.token1 = new(u256.Uint).Sub(pool.balances.token1, amount1)
	token1 := common.GetTokenTeller(pool.token1Path)
	checkTransferError(token1.Transfer(recipient, amount1.Uint64()))

	pool.positions[positionKey] = position

	return amount0.ToString(), amount1.ToString()
}

// collectToken handles the collection of tokens (either token0 or token1) from a position.
// It calculates the actual amount that can be collected based on three constraints:
// the requested amount, tokens owed, and available pool balance.
//
// Parameters:
//   - amountReq: amount requested to collect
//   - tokensOwed: amount of tokens owed to the position
//   - poolBalance: current balance of tokens in the pool
//
// Returns:
//   - amount: actual amount that will be collected (minimum of the three inputs)
//   - newTokensOwed: remaining tokens owed after collection
//   - newPoolBalance: remaining pool balance after collection
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

// setFeeProtocol updates the protocol fee configuration for all existing pools and sets
// the default for new pools. This is an internal function called by both `admin` and `governance`
// protocol fee management functions.
//
// The protocol fee is stored as a single `uint8` value where:
//   - Lower 4 bits store feeProtocol0 (for token0)
//   - Upper 4 bits store feeProtocol1 (for token1)
//
// This compact representation allows storing both fee values in a single byte.
//
// Parameters (must be 0 or between 4 and 10 inclusive):
//   - feeProtocol0: protocol fee for token0
//   - feeProtocol1: protocol fee for token1
//
// Returns:
//   - newFee (uint8): the combined fee protocol value
//
// Example:
// If feeProtocol0 = 4 and feeProtocol1 = 5:
//
//	newFee = 4 + (5 << 4)
//	// Results in: 0x54 (84 in decimal)
//	// Binary: 0101 0100
//	//         ^^^^ ^^^^
//	//       fee1=5  fee0=4
func setFeeProtocol(feeProtocol0, feeProtocol1 uint8) uint8 {
	common.IsHalted()

	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		panic(addDetailToError(
			err,
			ufmt.Sprintf("expected (feeProtocol0(%d) == 0 || (feeProtocol0(%d) >= 4 && feeProtocol0(%d) <= 10)) && (feeProtocol1(%d) == 0 || (feeProtocol1(%d) >= 4 && feeProtocol1(%d) <= 10))", feeProtocol0, feeProtocol0, feeProtocol0, feeProtocol1, feeProtocol1, feeProtocol1),
		))
	}

	// combine both protocol fee into a single byte:
	// - feePrtocol0 occupies the lower 4 bits
	// - feeProtocol1 is shifted the lower 4 positions to occupy the upper 4 bits
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

// isValidFeeProtocolValue checks if a fee protocol value is within acceptable range.
// valid values are either 0 or between 4 and 10 inclusive.
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
	amount0Requested string, // uint128
	amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

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
	amount0Requested string, // uint128
	amount1Requested string, // uint128
) (string, string) { // uint128 x2
	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

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

	token0Teller := common.GetTokenTeller(pool.token0Path)
	checkTransferError(token0Teller.Transfer(recipient, uAmount0))

	token1Teller := common.GetTokenTeller(pool.token1Path)
	checkTransferError(token1Teller.Transfer(recipient, uAmount1))

	return amount0.ToString(), amount1.ToString()
}

// saveProtocolFees updates the protocol fee balances after collection.
//
// Parameters:
//   - amount0: amount of token0 fees to collect
//   - amount1: amount of token1 fees to collect
//
// Returns the adjusted amounts that will actually be collected for both tokens.
func (p *Pool) saveProtocolFees(amount0, amount1 *u256.Uint) (*u256.Uint, *u256.Uint) {
	cond01 := amount0.Gt(u256.Zero())
	cond02 := amount0.Eq(p.protocolFees.token0)
	if cond01 && cond02 {
		amount0 = new(u256.Uint).Sub(amount0, u256.One())
	}

	cond11 := amount1.Gt(u256.Zero())
	cond12 := amount1.Eq(p.protocolFees.token1)
	if cond11 && cond12 {
		amount1 = new(u256.Uint).Sub(amount1, u256.One())
	}

	p.protocolFees.token0 = new(u256.Uint).Sub(p.protocolFees.token0, amount0)
	p.protocolFees.token1 = new(u256.Uint).Sub(p.protocolFees.token1, amount1)

	// return rest fee
	return amount0, amount1
}
