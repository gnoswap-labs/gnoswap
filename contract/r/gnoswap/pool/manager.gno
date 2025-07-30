package pool

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"

	en "gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/gnoswap/v1/gns"
)

const GNS_PATH string = "gno.land/r/gnoswap/v1/gns"

var (
	feeAmountTickSpacing = avl.NewTree() // feeBps(uint32) -> tickSpacing(int32)
	pools                = avl.NewTree() // poolPath -> *Pool

	slot0FeeProtocol uint8 = 0
)

func init() {
	setFeeAmountTickSpacing(100, 1)     // 0.01%
	setFeeAmountTickSpacing(500, 10)    // 0.05%
	setFeeAmountTickSpacing(3000, 60)   // 0.3%
	setFeeAmountTickSpacing(10000, 200) // 1%
}

// CreatePool creates a new concentrated liquidity pool with the given parameters.
// It mints and distributes GNS tokens, validates the input parameters, and creates a new pool.
// If GNOT is used as one of the tokens, it is automatically wrapped to WUGNOT.
// The function ensures that token0Path is lexicographically smaller than token1Path.
// ref: https://docs.gnoswap.io/contracts/pool/pool_manager.gno#createpool
func CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	halt.AssertIsNotHaltedPool()

	assertIsNotEqualsTokens(token0Path, token1Path)
	assertIsSupportedFeeTier(fee)
	assertIsNotExistsPoolPath(token0Path, token1Path, fee)

	en.MintAndDistributeGns(cross)

	poolInfo := newPoolParams(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
		GetFeeAmountTickSpacing(fee),
	)

	poolInfo, err := poolInfo.updateWithWrapping()
	if err != nil {
		panic(err)
	}

	// check if wrapped token paths are registered
	common.MustRegistered(poolInfo.token0Path)
	common.MustRegistered(poolInfo.token1Path)

	pool := newPool(poolInfo)
	pools.Set(poolInfo.poolPath(), pool)

	if poolCreationFee > 0 {
		gns.TransferFrom(cross, std.PreviousRealm().Address(), protocolFeeAddr, poolCreationFee)
		pf.AddToProtocolFee(cross, GNS_PATH, uint64(poolCreationFee))

		previousRealm := std.PreviousRealm()
		std.Emit(
			"PoolCreationFee",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"poolPath", poolInfo.poolPath(),
			"feeTokenPath", GNS_PATH,
			"feeAmount", formatInt(poolCreationFee),
		)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"CreatePool",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", formatUint(fee),
		"sqrtPriceX96", sqrtPriceX96,
		"poolPath", pool.PoolPath(),
		"tick", formatInt(pool.Slot0Tick()),
		"tickSpacing", formatInt(poolInfo.TickSpacing()),
	)
}

// SetFeeProtocol sets the fee protocol for all pools
// Only governance contract can execute this function via proposal
// Also it will be applied to new created pools
// ref: https://docs.gnoswap.io/contracts/pool/pool.gno#setfeeprotocol
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	halt.AssertIsNotHaltedPool()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := setFeeProtocolInternal(feeProtocol0, feeProtocol1, "SetFeeProtocol")
	if err != nil {
		panic(err)
	}
}

// setFeeAmountTickSpacing associates a tick spacing value with a fee amount.
// This is typically called during initialization to set up supported fee tiers.
//
// Parameters:
//   - fee (uint32): The fee tier in basis points (e.g., 3000 for 0.3%)
//   - tickSpacing (int32): The minimum tick spacing for this fee tier
//
// Note: Smaller tick spacing allows for more granular price points but increases
// computational overhead. Higher fee tiers typically use larger tick spacing.
func setFeeAmountTickSpacing(fee uint32, tickSpacing int32) {
	feeStr := formatUint(fee)
	feeAmountTickSpacing.Set(feeStr, tickSpacing)
}

// mustGetPool retrieves a pool instance by its path and ensures it exists.
//
// This function attempts to fetch the pool by poolPath.
// If the pool does not exist, it panics with a detailed error message.
//
// Parameters:
//   - poolPath: The unique identifier for the pool.
//
// Returns:
//   - *Pool: A valid Pool instance.
//
// Panics:
//   - If the pool does not exist, an error is thrown with the message
//     "expected poolPath(<poolPath>) to exist".
func mustGetPool(poolPath string) *Pool {
	iPool, exist := pools.Get(poolPath)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("expected poolPath(%s) to exist", poolPath),
		))
	}

	return iPool.(*Pool)
}

func mustGetPoolBy(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return mustGetPool(poolPath)
}

// setFeeProtocolInternal updates the protocol fee for all pools and emits an event.
//
// This function is an internal utility used to set the protocol fee for token0 and token1 in a compact
// format. The fee values are stored as a single `uint8` byte where:
//   - Lower 4 bits represent the fee for token0 (feeProtocol0).
//   - Upper 4 bits represent the fee for token1 (feeProtocol1).
//
// It also emits an event to log the changes, including the previous and new fee protocol values.
//
// Parameters:
//   - feeProtocol0: uint8, protocol fee for token0 (must be 0 or between 4 and 10 inclusive).
//   - feeProtocol1: uint8, protocol fee for token1 (must be 0 or between 4 and 10 inclusive).
//   - eventName: string, the name of the event to emit (e.g., "SetFeeProtocol").
//
// Notes:
//   - This function is called by higher-level functions like `SetFeeProtocol` or `SetFeeProtocol`.
//   - It does not validate caller permissions; validation must be performed by the calling function.
func setFeeProtocolInternal(feeProtocol0, feeProtocol1 uint8, eventName string) error {
	oldFee := slot0FeeProtocol
	newFee, err := setFeeProtocol(feeProtocol0, feeProtocol1)
	if err != nil {
		return err
	}

	feeProtocol0Old := oldFee % 16
	feeProtocol1Old := oldFee >> 4

	previousRealm := std.PreviousRealm()
	std.Emit(
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
func setFeeProtocol(feeProtocol0, feeProtocol1 uint8) (uint8, error) {
	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		return 0, err
	}

	// combine both protocol fee into a single byte:
	// - feePrtocol0 occupies the lower 4 bits
	// - feeProtocol1 is shifted the lower 4 positions to occupy the upper 4 bits
	newFee := feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )

	// Update slot0 for each pool
	pools.Iterate("", "", func(poolPath string, iPool any) bool {
		pool := iPool.(*Pool)
		pool.slot0.feeProtocol = newFee

		return false
	})

	// update slot0
	slot0FeeProtocol = newFee
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
