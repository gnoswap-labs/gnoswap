package pool

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	en "gno.land/r/gnoswap/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/gnoswap/gns"
)

const GNS_PATH string = "gno.land/r/gnoswap/gns"

// NOTE: Global vars have been moved to KVStore-based storage via PoolV1
// These are kept for backward compatibility during migration
// TODO: Remove these after full migration
var (
	feeAmountTickSpacing = avl.NewTree() // DEPRECATED: use PoolV1
	pools                = avl.NewTree() // DEPRECATED: use PoolV1

	// slot0FeeProtocol represents the protocol fee percentage (0-10).
	// DEPRECATED: use PoolV1
	slot0FeeProtocol uint8 = 0
)

func init() {
	// DEPRECATED: Default fee tiers are now initialized in PoolV1.initializeDefaultFeeTiers()
	// This init() will be removed after full migration to PoolV1
	setFeeAmountTickSpacing(100, 1)     // 0.01%
	setFeeAmountTickSpacing(500, 10)    // 0.05%
	setFeeAmountTickSpacing(3000, 60)   // 0.3%
	setFeeAmountTickSpacing(10000, 200) // 1%
}


// setFeeAmountTickSpacing associates a tick spacing value with a fee amount.
func (pv1 *PoolV1) setFeeAmountTickSpacing(fee uint32, tickSpacing int32) {
	feeStr := formatUint(fee)
	feeAmountTickSpacing.Set(feeStr, tickSpacing)
}

// mustGetPool retrieves a pool instance by its path and ensures it exists.
func (pv1 *PoolV1) mustGetPool(poolPath string) (pool *Pool) {
	poolsTree := pv1.getPoolsTree()

	iPool, exist := poolsTree.Get(poolPath)
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
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return pv1.mustGetPool(poolPath)
}

// setFeeProtocolInternal updates the protocol fee for all pools and emits an event.
func (pv1 *PoolV1) setFeeProtocolInternal(feeProtocol0, feeProtocol1 uint8, eventName string) error {
	oldFee := slot0FeeProtocol
	newFee, err := setFeeProtocol(feeProtocol0, feeProtocol1)
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
func (pv1 *PoolV1) setFeeProtocol(feeProtocol0, feeProtocol1 uint8) (uint8, error) {
	if err := validateFeeProtocol(feeProtocol0, feeProtocol1); err != nil {
		return 0, err
	}

	// combine both protocol fee into a single byte:
	// - feePrtocol0 occupies the lower 4 bits
	// - feeProtocol1 is shifted the lower 4 positions to occupy the upper 4 bits
	newFee := feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )

	// Update slot0 for each pool
	pools.Iterate("", "", func(poolPath string, iPool any) bool {
		pool, ok := iPool.(*Pool)
		if !ok {
			panic("failed to cast pool to *Pool")
		}
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
func (pv1 *PoolV1) validateFeeProtocol(feeProtocol0, feeProtocol1 uint8) error {
	if !isValidFeeProtocolValue(feeProtocol0) || !isValidFeeProtocolValue(feeProtocol1) {
		return errInvalidProtocolFeePct
	}
	return nil
}

// isValidFeeProtocolValue checks if a fee protocol value is within acceptable range.
// valid values are either 0 or between 4 and 10 inclusive.
func (pv1 *PoolV1) isValidFeeProtocolValue(value uint8) bool {
	return value == 0 || (value >= 4 && value <= 10)
}
