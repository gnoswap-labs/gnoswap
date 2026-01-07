package v1

import (
	"chain"
	"chain/runtime"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"

	en "gno.land/r/gnoswap/emission"
	pf "gno.land/r/gnoswap/protocol_fee"

	"gno.land/r/gnoswap/gns"
)

const GNS_PATH string = "gno.land/r/gnoswap/gns"

// CreatePool creates a new concentrated liquidity pool.
//
// Deploys new AMM pool for token pair with specified fee tier.
// Charges 100 GNS creation fee to prevent spam.
// Sets initial price and tick spacing based on fee tier.
//
// Parameters:
//   - token0Path, token1Path: Token contract paths (ordered by address)
//   - fee: Fee tier (100=0.01%, 500=0.05%, 3000=0.3%, 10000=1%)
//   - sqrtPriceX96: Initial sqrt price in Q64.96 format
//
// Tick spacing by fee tier:
//   - 0.01%: 1 tick
//   - 0.05%: 10 ticks
//   - 0.30%: 60 ticks
//   - 1.00%: 200 ticks
//
// Requirements:
//   - Tokens must be different
//   - Fee tier must be supported
//   - Pool must not already exist
//   - Caller must have 100 GNS for creation fee
//
// IMPORTANT - Price Initialization Security:
//
//	The sqrtPriceX96 parameter allows arbitrary initial price setting without validation.
//	Extreme prices can make pools temporarily unusable (griefing attack).
//
// Recovery from Price Griefing:
//
//	If a pool is created with an incorrect price, it can be restored via atomic transaction:
//	1. Add wide-range liquidity at the distorted price
//	2. Execute swap to move price toward market rate
//	3. Remove the liquidity
//	The executor's LP losses offset arbitrage gains (minus fees).
func (i *poolV1) CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	halt.AssertIsNotHaltedPool()

	assertIsSupportedFeeTier(fee)
	assertIsNotExistsPoolPath(i, token0Path, token1Path, fee)

	en.MintAndDistributeGns(cross)

	slot0FeeProtocol := i.store.GetSlot0FeeProtocol()

	poolInfo := newPoolParams(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
		i.GetFeeAmountTickSpacing(fee),
		slot0FeeProtocol,
	)

	err := poolInfo.updateWithWrapping()
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

	err = i.store.SetPools(pools)
	if err != nil {
		panic(err)
	}

	poolCreationFee := i.store.GetPoolCreationFee()

	if poolCreationFee > 0 {
		protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())

		previousRealm := runtime.PreviousRealm()
		previousRealmAddr := previousRealm.Address()
		gns.TransferFrom(cross, previousRealmAddr, protocolFeeAddr, poolCreationFee)
		pf.AddToProtocolFee(cross, GNS_PATH, poolCreationFee)

		chain.Emit(
			"PoolCreationFee",
			"prevAddr", previousRealmAddr.String(),
			"prevRealm", previousRealm.PkgPath(),
			"poolPath", poolPath,
			"feeTokenPath", GNS_PATH,
			"feeAmount", formatInt(poolCreationFee),
		)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CreatePool",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", formatUint(fee),
		"sqrtPriceX96", sqrtPriceX96,
		"poolPath", poolPath,
		"tick", formatInt(pool.Slot0Tick()),
		"tickSpacing", formatInt(poolInfo.TickSpacing()),
	)
}

// SetFeeProtocol sets the protocol fee percentage for all pools.
//
// Parameters:
//   - feeProtocol0, feeProtocol1: fee percentages (0-10)
//
// Only callable by admin or governance.
func (i *poolV1) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	halt.AssertIsNotHaltedPool()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := i.setFeeProtocolInternal(feeProtocol0, feeProtocol1, "SetFeeProtocol")
	if err != nil {
		panic(err)
	}
}

// setFeeAmountTickSpacing associates a tick spacing value with a fee amount.
func (i *poolV1) setFeeAmountTickSpacing(fee uint32, tickSpacing int32) error {
	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()
	feeAmountTickSpacing[fee] = tickSpacing

	return i.store.SetFeeAmountTickSpacing(feeAmountTickSpacing)
}

func (i *poolV1) getPool(poolPath string) (*pl.Pool, error) {
	pools := i.store.GetPools()

	iPool, exist := pools.Get(poolPath)
	if !exist {
		return nil, ufmt.Errorf("expected poolPath(%s) to exist", poolPath)
	}

	p, ok := iPool.(*pl.Pool)
	if !ok {
		return nil, ufmt.Errorf("failed to cast pool to *Pool: %T", iPool)
	}

	return p, nil
}

// mustGetPool retrieves a pool instance by its path and ensures it exists.
func (i *poolV1) mustGetPool(poolPath string) (pool *pl.Pool) {
	p, err := i.getPool(poolPath)
	if err != nil {
		panic(makeErrorWithDetails(errDataNotFound, err.Error()))
	}

	return p
}

func (i *poolV1) mustGetPoolBy(token0Path, token1Path string, fee uint32) *pl.Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return i.mustGetPool(poolPath)
}

// savePool updates a pool in the pools map and persists to storage.
// This ensures that modifications to pool objects are properly saved.
func (i *poolV1) savePool(pool *pl.Pool) error {
	pools := i.store.GetPools()
	pools.Set(pool.PoolPath(), pool)

	return i.store.SetPools(pools)
}

// setFeeProtocolInternal updates the protocol fee for all pools and emits an event.
func (i *poolV1) setFeeProtocolInternal(feeProtocol0, feeProtocol1 uint8, eventName string) error {
	oldFee := i.store.GetSlot0FeeProtocol()
	newFee, err := i.setFeeProtocol(feeProtocol0, feeProtocol1)
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
		"prevFeeProtocol0", formatUint(feeProtocol0Old),
		"prevFeeProtocol1", formatUint(feeProtocol1Old),
		"feeProtocol0", formatUint(feeProtocol0),
		"feeProtocol1", formatUint(feeProtocol1),
		"newFee", formatUint(newFee),
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
//   - feeProtocol0: protocol fee for token0 (must be 0 or between 4 and 10 inclusive).
//   - feeProtocol1: protocol fee for token1 (must be 0 or between 4 and 10 inclusive).
//
// Returns:
//   - newFee (uint8): the combined fee protocol value.
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
func (i *poolV1) setFeeProtocol(feeProtocol0, feeProtocol1 uint8) (uint8, error) {
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
	err := i.store.SetSlot0FeeProtocol(newFee)
	if err != nil {
		return 0, err
	}

	return newFee, nil
}

// validateFeeProtocol validates the fee protocol values for token0 and token1.
//
// This function checks whether the provided fee protocol values (`feeProtocol0` and `feeProtocol1`)
// are valid using the `isValidFeeProtocolValue` function. If either value is invalid, it returns
// an error indicating that the protocol fee percentage is invalid.
//
// Parameters:
//   - feeProtocol0: uint8, the fee protocol value for token0.
//   - feeProtocol1: uint8, the fee protocol value for token1.
//
// Returns:
//   - error: Returns `errInvalidProtocolFeePct` if either `feeProtocol0` or `feeProtocol1` is invalid.
//     Returns `nil` if both values are valid.
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
