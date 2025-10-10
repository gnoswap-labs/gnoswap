package pool

import (
	"chain"
	"chain/runtime"

	"gno.land/p/gnoswap/sys/storage"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	en "gno.land/r/gnoswap/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	prabc "gno.land/p/gnoswap/rbac"
)

const GNS_PATH string = "gno.land/r/gnoswap/gns"

var (
	positionAddr    = access.MustGetAddressWithVersion(prabc.ROLE_POSITION.String(), 1)
	poolAddr        = access.MustGetAddressWithVersion(prabc.ROLE_POOL.String(), 1)
	protocolFeeAddr = access.MustGetAddressWithVersion(prabc.ROLE_PROTOCOL_FEE.String(), 1)
	routerAddr      = access.MustGetAddressWithVersion(prabc.ROLE_ROUTER.String(), 1)
)

// PoolV1 implements the IPool interface with KVStore-based storage
type PoolV1 struct {
	store storage.KVStore
}

// NewPoolV1 creates a new PoolV1 instance with the given KVStore
func NewPoolV1(store storage.KVStore) *PoolV1 {
	pv1 := &PoolV1{
		store: store,
	}

	// Initialize default fee tier tick spacings if not already set
	pv1.initializeDefaultFeeTiers()

	return pv1
}

// initializeDefaultFeeTiers sets up the default fee tier to tick spacing mappings
func (pv1 *PoolV1) initializeDefaultFeeTiers() {
	feeTree := pv1.getFeeAmountTickSpacingTree()

	// Only initialize if tree is empty
	if feeTree.Size() == 0 {
		pv1.setFeeAmountTickSpacing(100, 1)     // 0.01%
		pv1.setFeeAmountTickSpacing(500, 10)    // 0.05%
		pv1.setFeeAmountTickSpacing(3000, 60)   // 0.3%
		pv1.setFeeAmountTickSpacing(10000, 200) // 1%
	}
}

// Storage helper methods

func (pv1 *PoolV1) getFeeAmountTickSpacingTree() *avl.Tree {
	val, err := pv1.store.Get(KEY_FEE_AMOUNT_TICK_SPACING, pv1.getCaller())
	if err != nil || val == nil {
		tree := avl.NewTree()
		pv1.store.Set(KEY_FEE_AMOUNT_TICK_SPACING, tree, pv1.getCaller())
		return tree
	}
	return val.(*avl.Tree)
}

func (pv1 *PoolV1) getPoolsTree() *avl.Tree {
	val, err := pv1.store.Get(KEY_POOLS, pv1.getCaller())
	if err != nil || val == nil {
		tree := avl.NewTree()
		pv1.store.Set(KEY_POOLS, tree, pv1.getCaller())
		return tree
	}
	return val.(*avl.Tree)
}

func (pv1 *PoolV1) getSlot0FeeProtocol() uint8 {
	val, err := pv1.store.Get(KEY_SLOT0_FEE_PROTOCOL, pv1.getCaller())
	if err != nil || val == nil {
		return 0
	}
	return val.(uint8)
}

func (pv1 *PoolV1) setSlot0FeeProtocol(feeProtocol uint8) {
	pv1.store.Set(KEY_SLOT0_FEE_PROTOCOL, feeProtocol, pv1.getCaller())
}

func (pv1 *PoolV1) getCaller() address {
	return runtime.CurrentRealm().Addr()
}

func (pv1 *PoolV1) setFeeAmountTickSpacing(fee uint32, tickSpacing int32) {
	tree := pv1.getFeeAmountTickSpacingTree()
	feeStr := pv1.formatUint(fee)
	tree.Set(feeStr, tickSpacing)
	pv1.store.Set(KEY_FEE_AMOUNT_TICK_SPACING, tree, pv1.getCaller())
}

func (pv1 *PoolV1) mustGetPool(poolPath string) *Pool {
	pools := pv1.getPoolsTree()
	iPool, exist := pools.Get(poolPath)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("expected poolPath(%s) to exist", poolPath),
		))
	}

	pool, ok := iPool.(*Pool)
	if !ok {
		panic(ufmt.Sprintf("failed to cast pool to *Pool: %T", iPool))
	}
	return pool
}

func (pv1 *PoolV1) mustGetPoolBy(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := pv1.GetPoolPath(token0Path, token1Path, fee)
	return pv1.mustGetPool(poolPath)
}

// IPool interface implementation

// CreatePool creates a new concentrated liquidity pool.
func (pv1 *PoolV1) CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	pv1.assertIsNotEqualsTokens(token0Path, token1Path)
	pv1.assertIsSupportedFeeTier(fee)
	pv1.assertIsNotExistsPoolPath(token0Path, token1Path, fee)

	en.MintAndDistributeGns(cross)

	poolInfo := pv1.newPoolParams(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
		pv1.GetFeeAmountTickSpacing(fee),
	)

	poolInfo, err := poolInfo.updateWithWrapping()
	if err != nil {
		panic(err)
	}

	// check if wrapped token paths are registered
	common.MustRegistered(poolInfo.token0Path)
	common.MustRegistered(poolInfo.token1Path)

	pool := newPool(poolInfo)
	pools := pv1.getPoolsTree()
	pools.Set(poolInfo.poolPath(), pool)
	pv1.store.Set(KEY_POOLS, pools, pv1.getCaller())

	poolCreationFee := getPoolCreationFee()
	if poolCreationFee > 0 {
		gns.TransferFrom(cross, runtime.PreviousRealm().Address(), protocolFeeAddr, poolCreationFee)
		pf.AddToProtocolFee(cross, GNS_PATH, poolCreationFee)

		previousRealm := runtime.PreviousRealm()
		chain.Emit(
			"PoolCreationFee",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"poolPath", poolInfo.poolPath(),
			"feeTokenPath", GNS_PATH,
			"feeAmount", pv1.formatInt(poolCreationFee),
		)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CreatePool",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", pv1.formatUint(fee),
		"sqrtPriceX96", sqrtPriceX96,
		"poolPath", pool.PoolPath(),
		"tick", pv1.formatInt(pool.Slot0Tick()),
		"tickSpacing", pv1.formatInt(poolInfo.TickSpacing()),
	)
}

// Mint adds liquidity to a pool position.
func (pv1 *PoolV1) Mint(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPositionWithVersion(1, caller)
	access.AssertIsValidAddress(positionCaller)

	liquidity := u256.MustFromDecimal(liquidityAmount)
	if liquidity.IsZero() {
		panic(errZeroLiquidity)
	}

	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)
	liquidityDelta := pv1.safeConvertToInt128(liquidity)
	positionParam := newModifyPositionParams(positionCaller, tickLower, tickUpper, liquidityDelta)
	_, amount0, amount1, err := pool.modifyPosition(positionParam)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(zero) {
		pool.safeTransferFrom(positionCaller, poolAddr, pool.token0Path, amount0, true)
	}

	if amount1.Gt(zero) {
		pool.safeTransferFrom(positionCaller, poolAddr, pool.token1Path, amount1, false)
	}

	// Update pool in storage
	pv1.updatePoolInStorage(pool)

	return amount0.ToString(), amount1.ToString()
}

// Burn removes liquidity from a position.
func (pv1 *PoolV1) Burn(
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPositionWithVersion(1, caller)
	access.AssertIsValidAddress(positionCaller)

	liqAmount := u256.MustFromDecimal(liquidityAmount)
	liqAmountInt256 := pv1.safeConvertToInt128(liqAmount)
	liqDelta := i256.Zero().Neg(liqAmountInt256)

	posParams := newModifyPositionParams(positionCaller, tickLower, tickUpper, liqDelta)
	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)
	position, amount0, amount1, err := pool.modifyPosition(posParams)
	if err != nil {
		panic(err)
	}

	if amount0.Gt(zero) || amount1.Gt(zero) {
		amount0 = pv1.toUint128(amount0)
		amount1 = pv1.toUint128(amount1)

		tokensOwed0, overflow := u256.Zero().AddOverflow(position.tokensOwed0, amount0)
		if overflow {
			panic(errOverFlow)
		}
		position.tokensOwed0 = tokensOwed0

		tokensOwed1, overflow := u256.Zero().AddOverflow(position.tokensOwed1, amount1)
		if overflow {
			panic(errOverFlow)
		}
		position.tokensOwed1 = tokensOwed1
	}

	positionKey, err := pv1.getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	pool.setPosition(positionKey, position)
	pool.mustGetPosition(positionKey)

	// Update pool in storage
	pv1.updatePoolInStorage(pool)

	return amount0.ToString(), amount1.ToString()
}

// Collect transfers owed tokens from a position to recipient.
func (pv1 *PoolV1) Collect(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsPositionWithVersion(1, caller)
	access.AssertIsValidAddress(recipient)

	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)
	positionKey, err := pv1.getPositionKey(tickLower, tickUpper)
	if err != nil {
		panic(err)
	}

	position := pool.mustGetPosition(positionKey)

	var amount0, amount1 *u256.Uint

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount0 = collectToken(amount0Req, position.tokensOwed0, pool.BalanceToken0())

	amount1Req := u256.MustFromDecimal(amount1Requested)
	amount1 = collectToken(amount1Req, position.tokensOwed1, pool.BalanceToken1())

	if amount0.Gt(u256.Zero()) {
		tokenOwed0, overflow := u256.Zero().SubOverflow(position.tokensOwed0, amount0)
		if overflow {
			panic(errOverFlow)
		}

		token0Balance, overflow := u256.Zero().SubOverflow(pool.balances.token0, amount0)
		if overflow {
			panic(errOverFlow)
		}

		position.tokensOwed0 = tokenOwed0
		pool.balances.token0 = token0Balance
		common.SafeGRC20Approve(cross, pool.token0Path, positionAddr, pv1.safeConvertToInt64(amount0))
	}
	if amount1.Gt(u256.Zero()) {
		position.tokensOwed1 = u256.Zero().Sub(position.tokensOwed1, amount1)
		pool.balances.token1 = u256.Zero().Sub(pool.balances.token1, amount1)
		common.SafeGRC20Approve(cross, pool.token1Path, positionAddr, pv1.safeConvertToInt64(amount1))
	}

	pool.setPosition(positionKey, position)

	// Update pool in storage
	pv1.updatePoolInStorage(pool)

	return amount0.ToString(), amount1.ToString()
}

// CollectProtocol collects accumulated protocol fees.
func (pv1 *PoolV1) CollectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	common.MustRegistered(token0Path)
	common.MustRegistered(token1Path)

	amount0, amount1 := pv1.collectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CollectProtocol",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", pv1.formatUint(fee),
		"recipient", recipient.String(),
		"internal_amount0", amount0,
		"internal_amount1", amount1,
	)

	return amount0, amount1
}

// Swap executes a token swap.
func (pv1 *PoolV1) Swap(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	caller address,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	previousCaller := runtime.PreviousRealm().Address()
	access.AssertIsRouterWithVersion(1, previousCaller)
	access.AssertIsValidAddress(caller)

	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)

	amount0, amount1, err := pool.swap(
		recipient,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
		caller,
	)
	if err != nil {
		panic(err)
	}

	// Update pool in storage
	pv1.updatePoolInStorage(pool)

	return amount0, amount1
}

// DrySwap simulates a swap without executing it.
func (pv1 *PoolV1) DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)

	// Clone pool for dry run
	poolClone := pool.Clone()

	amount0, amount1, err := poolClone.swap(
		runtime.PreviousRealm().Address(),
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
		runtime.PreviousRealm().Address(),
	)
	if err != nil {
		panic(err)
	}

	return amount0, amount1
}

// SetFeeProtocol sets the protocol fee percentage.
func (pv1 *PoolV1) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	halt.AssertIsNotHaltedPoolWithVersion(1)

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernanceWithVersion(1, caller)

	err := pv1.setFeeProtocolInternal(feeProtocol0, feeProtocol1, "SetFeeProtocol")
	if err != nil {
		panic(err)
	}
}

// GetPoolPath returns the pool path for given tokens and fee.
func (pv1 *PoolV1) GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return GetPoolPath(token0Path, token1Path, fee)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price.
func (pv1 *PoolV1) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	pool := pv1.mustGetPool(poolPath)
	return pool.Slot0SqrtPriceX96()
}

// GetSlot0Tick returns the current tick.
func (pv1 *PoolV1) GetSlot0Tick(poolPath string) int32 {
	pool := pv1.mustGetPool(poolPath)
	return pool.Slot0Tick()
}

// GetLiquidity returns current liquidity.
func (pv1 *PoolV1) GetLiquidity(poolPath string) string {
	pool := pv1.mustGetPool(poolPath)
	return pool.Liquidity().ToString()
}

// GetBalanceToken0 returns token0 balance.
func (pv1 *PoolV1) GetBalanceToken0(poolPath string) string {
	pool := pv1.mustGetPool(poolPath)
	return pool.BalanceToken0().ToString()
}

// GetBalanceToken1 returns token1 balance.
func (pv1 *PoolV1) GetBalanceToken1(poolPath string) string {
	pool := pv1.mustGetPool(poolPath)
	return pool.BalanceToken1().ToString()
}

// GetFeeGrowthGlobalX128 returns global fee growth values.
func (pv1 *PoolV1) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	pool := pv1.mustGetPool(poolPath)
	return pool.FeeGrowthGlobal0X128(), pool.FeeGrowthGlobal1X128()
}

// GetPositionFeeGrowthInsideLastX128 returns position fee growth.
func (pv1 *PoolV1) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	pool := pv1.mustGetPool(poolPath)
	position := pool.mustGetPosition(key)
	return position.feeGrowthInside0LastX128, position.feeGrowthInside1LastX128
}

// GetObservation returns oracle observation data.
func (pv1 *PoolV1) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	pool := pv1.mustGetPool(poolPath)
	return pool.ObservationTickCumulative(),
		pool.ObservationLiquidityCumulative(),
		pool.ObservationSecondsPerLiquidityCumulativeX128(),
		pool.ObservationBlockTimestamp()
}

// ExistsPoolPath checks if pool exists.
func (pv1 *PoolV1) ExistsPoolPath(poolPath string) bool {
	pools := pv1.getPoolsTree()
	return pools.Has(poolPath)
}

// ApiGetPool returns pool data as JSON.
func (pv1 *PoolV1) ApiGetPool(poolPath string) string {
	if !pv1.ExistsPoolPath(poolPath) {
		return ""
	}

	return ApiGetPool(poolPath)
}

// ApiGetTWAP returns time-weighted average price.
func (pv1 *PoolV1) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return ApiGetTWAP(poolPath, secondsAgo)
}

// Helper methods

func (pv1 *PoolV1) updatePoolInStorage(pool *Pool) {
	pools := pv1.getPoolsTree()
	pools.Set(pool.PoolPath(), pool)
	pv1.store.Set(KEY_POOLS, pools, pv1.getCaller())
}

func (pv1 *PoolV1) GetFeeAmountTickSpacing(fee uint32) int32 {
	tree := pv1.getFeeAmountTickSpacingTree()
	feeStr := pv1.formatUint(fee)

	spacing, exist := tree.Get(feeStr)
	if !exist {
		panic(newErrorWithDetail(
			errInvalidFeeTier,
			ufmt.Sprintf("fee tier %d not supported", fee),
		))
	}

	return spacing.(int32)
}

func (pv1 *PoolV1) assertIsSupportedFeeTier(fee uint32) {
	tree := pv1.getFeeAmountTickSpacingTree()
	feeStr := pv1.formatUint(fee)

	if !tree.Has(feeStr) {
		panic(newErrorWithDetail(
			errInvalidFeeTier,
			ufmt.Sprintf("fee tier %d not supported", fee),
		))
	}
}

func (pv1 *PoolV1) assertIsNotExistsPoolPath(token0Path, token1Path string, fee uint32) {
	poolPath := pv1.GetPoolPath(token0Path, token1Path, fee)
	if pv1.ExistsPoolPath(poolPath) {
		panic(newErrorWithDetail(
			errPoolAlreadyExists,
			ufmt.Sprintf("pool already exists: %s", poolPath),
		))
	}
}

func (pv1 *PoolV1) collectProtocol(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	pool := pv1.mustGetPoolBy(token0Path, token1Path, fee)

	amount0Req := u256.MustFromDecimal(amount0Requested)
	amount1Req := u256.MustFromDecimal(amount1Requested)
	if amount0Req.IsZero() && amount1Req.IsZero() {
		return "0", "0"
	}

	amount0 := pv1.u256Min(amount0Req, pool.ProtocolFeesToken0())
	amount1 := pv1.u256Min(amount1Req, pool.ProtocolFeesToken1())

	amount0, amount1 = pool.saveProtocolFees(amount0.Clone(), amount1.Clone())
	uAmount0 := pv1.safeConvertToInt64(amount0)
	uAmount1 := pv1.safeConvertToInt64(amount1)

	common.SafeGRC20Transfer(cross, pool.token0Path, recipient, uAmount0)
	newBalanceToken0, err := pv1.updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount0, true)
	if err != nil {
		panic(err)
	}
	pool.balances.token0 = newBalanceToken0

	common.SafeGRC20Transfer(cross, pool.token1Path, recipient, uAmount1)
	newBalanceToken1, err := pv1.updatePoolBalance(pool.BalanceToken0(), pool.BalanceToken1(), amount1, false)
	if err != nil {
		panic(err)
	}
	pool.balances.token1 = newBalanceToken1

	// Update pool in storage
	pv1.updatePoolInStorage(pool)

	return amount0.ToString(), amount1.ToString()
}

func (pv1 *PoolV1) setFeeProtocolInternal(feeProtocol0, feeProtocol1 uint8, eventName string) error {
	oldFee := pv1.getSlot0FeeProtocol()
	newFee, err := pv1.setFeeProtocol(feeProtocol0, feeProtocol1)
	if err != nil {
		return err
	}

	feeProtocol0Old := oldFee % 16
	feeProtocol1Old := oldFee >> 4

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		eventName,
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFeeProtocol0", pv1.formatUint(feeProtocol0Old),
		"prevFeeProtocol1", pv1.formatUint(feeProtocol1Old),
		"feeProtocol0", pv1.formatUint(feeProtocol0),
		"feeProtocol1", pv1.formatUint(feeProtocol1),
		"newFee", pv1.formatUint(newFee),
	)

	return nil
}

func (pv1 *PoolV1) setFeeProtocol(feeProtocol0, feeProtocol1 uint8) (uint8, error) {
	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		return 0, err
	}

	newFee := feeProtocol0 + (feeProtocol1 << 4)

	// Update slot0 for each pool
	pools := pv1.getPoolsTree()
	pools.Iterate("", "", func(poolPath string, iPool any) bool {
		pool, ok := iPool.(*Pool)
		if !ok {
			panic("failed to cast pool to *Pool")
		}
		pool.slot0.feeProtocol = newFee
		return false
	})

	// Save updated pools
	pv1.store.Set(KEY_POOLS, pools, pv1.getCaller())

	// update global slot0FeeProtocol
	pv1.setSlot0FeeProtocol(newFee)

	return newFee, nil
}
