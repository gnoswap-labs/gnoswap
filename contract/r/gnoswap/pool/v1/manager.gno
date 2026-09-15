package pool

import (
	"chain"
	"errors"
	"time"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	gns "gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"

	en "gno.land/r/gnoswap/emission"
)

const GNS_TOKEN_KEY string = "gno.land/r/gnoswap/gns.GNS"

// CreatePool creates a new concentrated liquidity pool.
//
// Deploys a new AMM pool for a token pair with the specified fee tier.
// Charges the configured pool-creation fee (100 GNS by default).
// Accepts either token path order, canonicalizes token0/token1, and sets the
// initial price and tick spacing for that canonical order.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the pool proxy.
//   - token0Path: first token contract path; either order is accepted and the
//     stored pair is canonicalized.
//   - token1Path: second token contract path; either order is accepted and the
//     stored pair is canonicalized.
//   - fee: supported pool fee tier (100=0.01%, 500=0.05%, 3000=0.3%, 10000=1%).
//   - sqrtPriceX96: initial square-root price in Q64.96 format, constrained to
//     [MIN_SQRT_RATIO, MAX_SQRT_RATIO).
//
// Tick spacing by fee tier:
//   - 0.01%: 1 tick
//   - 0.05%: 10 ticks
//   - 0.30%: 60 ticks
//   - 1.00%: 200 ticks
//
// Requirements:
//   - Tokens must be different after canonicalization/wrapping
//   - Fee tier must be supported
//   - Pool must not already exist
//   - Caller must have the configured creation fee
//
// Price initialization:
//   - The initial sqrt price must be in [MIN_SQRT_RATIO, MAX_SQRT_RATIO).
//   - No oracle or external market-price sanity check is performed.
//   - If paths are supplied in reverse order, the stored sqrt price is
//     inverted to match the canonical token0/token1 order.
//
// Recovery from an economically inappropriate price:
//  1. Add wide-range liquidity at the current price.
//  2. Execute a swap to move the price toward the desired market rate.
//  3. Remove the liquidity.
//
// The executor's LP losses offset arbitrage gains, minus fees and slippage.
func (i *poolV1) CreatePool(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	assertIsSupportedFeeTier(fee)
	assertIsNotExistsPoolPath(i, token0Path, token1Path, fee)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	en.MintAndDistributeGns(cross(rlm))

	slot0FeeProtocol := i.store.GetSlot0FeeProtocol()

	tickSpacing, err := i.GetFeeAmountTickSpacing(fee)
	if err != nil {
		panic(err)
	}

	poolInfo := newPoolParams(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
		tickSpacing,
		slot0FeeProtocol,
	)

	err = poolInfo.update()
	if err != nil {
		panic(err)
	}

	// validate token paths are not the same after wrapping
	assertIsNotEqualsTokens(poolInfo.token0Path, poolInfo.token1Path)

	// check if wrapped token paths are registered
	common.MustRegistered(poolInfo.token0Path, poolInfo.token1Path)

	pool := newPool(poolInfo)
	poolPath := poolInfo.poolPath()

	pools := i.store.GetPools()
	pools.Set(poolPath, pool)

	err = i.store.SetPools(0, rlm, pools)
	if err != nil {
		panic(err)
	}

	observations := i.store.GetObservations()
	observations.Set(poolPath, pl.NewPoolObservationsTree(time.Now().Unix()))
	if err := i.store.SetObservations(0, rlm, observations); err != nil {
		panic(err)
	}

	poolCreationFee := i.store.GetPoolCreationFee()

	if poolCreationFee > 0 {
		previousRealm := rlm.Previous()
		previousRealmAddr := previousRealm.Address()
		poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())
		gns.TransferFrom(cross(rlm), previousRealmAddr, poolAddr, poolCreationFee)

		chain.Emit(
			"PoolCreationFee",
			"prevAddr", previousRealmAddr.String(),
			"prevRealm", previousRealm.PkgPath(),
			"poolPath", poolPath,
			"feeTokenPath", GNS_TOKEN_KEY,
			"feeAmount", utils.FormatInt(poolCreationFee),
		)
	}

	i.settleProtocolFee(0, rlm, GNS_TOKEN_KEY, poolCreationFee)

	previousRealm := rlm.Previous()
	chain.Emit(
		"CreatePool",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", poolInfo.Token0Path(),
		"token1Path", poolInfo.Token1Path(),
		"fee", utils.FormatUint(fee),
		"sqrtPriceX96", poolInfo.SqrtPriceX96().ToString(),
		"poolPath", poolPath,
		"tick", utils.FormatInt(pool.Slot0Tick()),
		"tickSpacing", utils.FormatInt(poolInfo.TickSpacing()),
	)
}

// SetFeeProtocol sets the protocol fee denominators for all managed pools.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the pool proxy.
//   - feeProtocol0: token0 protocol-fee denominator; must be 0 or 4-10.
//     Zero disables protocol fees; 4 routes one quarter of swap fees and 10
//     routes one tenth to the protocol.
//   - feeProtocol1: token1 protocol-fee denominator with the same 0 or 4-10
//     constraint and fee share semantics as feeProtocol0.
//
// Only callable by admin or governance.
func (i *poolV1) SetFeeProtocol(_ int, rlm realm, feeProtocol0, feeProtocol1 uint8) {
	access.AssertIsRlmCurrent(0, rlm)

	i.assertPoolUnlocked()
	halt.AssertIsNotHaltedPool()

	caller := rlm.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	i.lockPool(0, rlm)
	defer i.unlockPool(0, rlm)

	err := i.setFeeProtocolInternal(0, rlm, feeProtocol0, feeProtocol1)
	if err != nil {
		panic(err)
	}
}

// setFeeAmountTickSpacing associates a tick spacing value with a fee amount.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context forwarded to storage, which validates it is
//     current before writing.
//   - fee: fee tier key to associate with tickSpacing.
//   - tickSpacing: signed spacing between usable initialized ticks for fee.
//
// Returns:
//   - err: nil when the fee mapping is stored; the storage error otherwise.
func (i *poolV1) setFeeAmountTickSpacing(_ int, rlm realm, fee uint32, tickSpacing int32) error {
	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()
	feeAmountTickSpacing[fee] = tickSpacing

	return i.store.SetFeeAmountTickSpacing(0, rlm, feeAmountTickSpacing)
}

// Parameters:
//   - poolPath: canonical pool identifier to retrieve.
//
// Returns:
//   - pool: stored pool instance when poolPath exists and has the expected type.
//   - err: descriptive error when the pool is absent or cannot be cast to
//     *pl.Pool.
func (i *poolV1) getPool(poolPath string) (*pl.Pool, error) {
	pools := i.store.GetPools()

	iPool := pools.Get(poolPath)
	if iPool == nil {
		return nil, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	p, ok := iPool.(*pl.Pool)
	if !ok {
		return nil, ufmt.Errorf("failed to cast pool to *Pool: %T", iPool)
	}

	return p, nil
}

// mustGetPool retrieves a pool instance by its path and ensures it exists.
// Parameters:
//   - poolPath: canonical pool identifier to retrieve.
//
// Returns:
//   - pool: stored pool instance; panics with errDataNotFound when lookup fails.
func (i *poolV1) mustGetPool(poolPath string) (pool *pl.Pool) {
	p, err := i.getPool(poolPath)
	if err != nil {
		panic(makeErrorWithDetails(errDataNotFound, err.Error()))
	}

	return p
}

// Parameters:
//   - token0Path: first token contract path used to derive a canonical pool path.
//   - token1Path: second token contract path used to derive a canonical pool path.
//   - fee: fee tier included in the derived pool path.
//
// Returns:
//   - pool: stored pool for the derived path; panics with errDataNotFound when it
//     does not exist.
func (i *poolV1) mustGetPoolBy(token0Path, token1Path string, fee uint32) *pl.Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return i.mustGetPool(poolPath)
}

// Parameters:
//   - poolPath: canonical pool identifier whose observation tree is retrieved.
//
// Returns:
//   - observations: stored observation tree for poolPath.
//   - err: descriptive error when the tree is absent or has the wrong type.
func (i *poolV1) getObservations(poolPath string) (*pl.ObservationTree, error) {
	observations := i.store.GetObservations()
	value := observations.Get(poolPath)
	if value == nil {
		return nil, ufmt.Errorf("expected observations for poolPath(%s) to exist", poolPath)
	}

	tree, ok := value.(*pl.ObservationTree)
	if !ok {
		return nil, ufmt.Errorf("failed to cast observations for poolPath(%s): %T", poolPath, value)
	}

	return tree, nil
}

// Parameters:
//   - poolPath: canonical pool identifier whose observation tree is retrieved.
//
// Returns:
//   - observations: stored observation tree; panics with errDataNotFound when
//     lookup fails.
func (i *poolV1) mustGetObservations(poolPath string) *pl.ObservationTree {
	tree, err := i.getObservations(poolPath)
	if err != nil {
		panic(makeErrorWithDetails(errDataNotFound, err.Error()))
	}
	return tree
}

// savePool updates a pool in the pools map and persists to storage.
// This ensures that modifications to pool objects are properly saved.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context forwarded to storage, which validates it is
//     current before writing.
//   - pool: non-nil pool instance to place under its own canonical pool path.
//
// Returns:
//   - err: nil when the updated pool tree is persisted; the storage error
//     otherwise.
func (i *poolV1) savePool(_ int, rlm realm, pool *pl.Pool) error {
	pools := i.store.GetPools()
	pools.Set(pool.PoolPath(), pool)

	return i.store.SetPools(0, rlm, pools)
}

// setFeeProtocolInternal updates the protocol fee for all pools and emits an event.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context used for the pool-wide protocol-fee update.
//   - feeProtocol0: token0 protocol-fee denominator; must be 0 or 4-10.
//   - feeProtocol1: token1 protocol-fee denominator; must be 0 or 4-10.
//
// Returns:
//   - err: nil after all pool slot0 values and the update event are processed;
//     validation or persistent-configuration error otherwise.
func (i *poolV1) setFeeProtocolInternal(_ int, rlm realm, feeProtocol0, feeProtocol1 uint8) error {
	oldFee := i.store.GetSlot0FeeProtocol()
	newFee, err := i.setFeeProtocol(0, rlm, feeProtocol0, feeProtocol1)
	if err != nil {
		return err
	}

	feeProtocol0Old := oldFee % 16
	feeProtocol1Old := oldFee >> 4

	previousRealm := rlm.Previous()
	chain.Emit(
		"SetFeeProtocol",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFeeProtocol0", utils.FormatUint(feeProtocol0Old),
		"prevFeeProtocol1", utils.FormatUint(feeProtocol1Old),
		"feeProtocol0", utils.FormatUint(feeProtocol0),
		"feeProtocol1", utils.FormatUint(feeProtocol1),
		"newFee", utils.FormatUint(newFee),
	)

	return nil
}

// setFeeProtocol updates the protocol fee configuration for all managed pools.
//
// This function combines the protocol fee values for token0 and token1 into a single `uint8` value,
// where:
//   - Lower 4 bits store feeProtocol0 (for token0).
//   - Upper 4 bits store feeProtocol1 (for token1).
//
// The updated fee protocol is applied uniformly to all pools managed by the system.
//
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context forwarded to each pool and storage update.
//   - feeProtocol0: token0 protocol-fee denominator (0 or 4-10 inclusive).
//   - feeProtocol1: token1 protocol-fee denominator (0 or 4-10 inclusive).
//
// Returns:
//   - newFee: packed uint8 with feeProtocol0 in the lower four bits and
//     feeProtocol1 in the upper four bits.
//   - err: nil after every pool and persistent slot0 configuration is updated;
//     validation or storage error otherwise.
//
// Example:
// If feeProtocol0 = 4 and feeProtocol1 = 5:
//
//	newFee = 4 + (5 << 4)
//	// Results in: 0x54 (84 in decimal)
//	// Binary: 0101 0100
//	//         ^^^^ ^^^^
//	//       fee1=5  fee0=4
//
// Notes:
//   - This function ensures that all pools under management are updated to use the same fee protocol.
//   - Caller restrictions (e.g., admin or governance) are not enforced in this function.
//   - Ensure the system is not halted before updating fees.
func (i *poolV1) setFeeProtocol(_ int, rlm realm, feeProtocol0, feeProtocol1 uint8) (uint8, error) {
	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		return 0, err
	}

	// combine both protocol fee into a single byte:
	// - feePrtocol0 occupies the lower 4 bits
	// - feeProtocol1 is shifted the lower 4 positions to occupy the upper 4 bits
	newFee := feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )

	pools := i.store.GetPools()

	// Update slot0 for each pool
	pools.Iterate("", "", func(poolPath string, poolI any) bool {
		pool, ok := poolI.(*pl.Pool)
		if !ok {
			panic(ufmt.Errorf("failed to cast pool to *Pool: %T", pool))
		}

		slot0 := pool.Slot0()
		slot0.SetFeeProtocol(newFee)

		pool.SetSlot0(slot0)
		return false
	})

	// update slot0
	err := i.store.SetSlot0FeeProtocol(0, rlm, newFee)
	if err != nil {
		return 0, err
	}

	return newFee, nil
}

// validateFeeProtocol validates the protocol fee denominators for token0 and
// token1. Each value must be 0 (disabled) or between 4 and 10 inclusive.
//
// Parameters:
//   - feeProtocol0: denominator for token0
//   - feeProtocol1: denominator for token1
//
// Returns:
//   - error: the existing errInvalidProtocolFeePct error when either
//     denominator is invalid; nil when both values are valid.
func validateFeeProtocol(feeProtocol0, feeProtocol1 uint8) error {
	if !isValidFeeProtocolValue(feeProtocol0) || !isValidFeeProtocolValue(feeProtocol1) {
		return errors.New(errInvalidProtocolFeePct)
	}
	return nil
}

// isValidFeeProtocolValue checks if a fee protocol value is within acceptable range.
// Valid values are either 0 (disabled) or between 4 and 10 inclusive.
//
// The value is used as a denominator: protocolFee = swapFee / feeProtocol
// (e.g., feeProtocol=4 means 1/4 = 25% of swap fees go to protocol)
//
// Parameters:
//   - value: Protocol-fee denominator to validate; zero disables the fee.
//
// Returns:
//   - valid: true when value is zero (protocol fees disabled) or between 4 and
//     10 inclusive; false for every other denominator.
func isValidFeeProtocolValue(value uint8) bool {
	return value == 0 || (value >= 4 && value <= 10)
}
