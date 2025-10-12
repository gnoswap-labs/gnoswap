package v1

import (
	"chain"
	"chain/runtime"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	pf "gno.land/r/gnoswap/v1/protocol_fee"
)

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
func (p *poolV1) CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	// NOTE: Halt does not manage versions.
	// Since only one instance is activated using the proxy pattern, versions are not specified.
	halt.AssertIsNotHaltedPool()

	assertIsNotEqualsTokens(token0Path, token1Path)
	assertIsSupportedFeeTier(fee)

	pools := p.store.GetPools()
	assertIsNotExistsPoolPath(pools, token0Path, token1Path, fee)

	emission.MintAndDistributeGns(cross)

	tickSpacing := p.GetFeeAmountTickSpacing(fee)
	slot0FeeProtocol := p.store.GetSlot0FeeProtocol()

	poolInfo := newPoolParams(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
		tickSpacing,
		slot0FeeProtocol,
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

	poolCreationFee := p.store.GetPoolCreationFee()
	protocolFeeAddr := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())

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
		"poolPath", pool.PoolPath(),
		"tick", formatInt(pool.Slot0Tick()),
		"tickSpacing", formatInt(poolInfo.TickSpacing()),
	)
}

// SetPoolCreationFee sets the poolCreationFee.
// Only admin or governance can call this function.
func (p *poolV1) SetPoolCreationFee(
	poolCreationFee int64,
) {
	// NOTE: Halt does not manage versions.
	// Since only one instance is activated using the proxy pattern, versions are not specified.
	halt.AssertIsNotHaltedPool()

	// NOTE: Access does not manage versions.
	// Since only one instance is activated using the proxy pattern, versions are not specified.
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	prevPoolCreationFee := p.store.GetPoolCreationFee()

	err := p.store.SetPoolCreationFee(poolCreationFee)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetPoolCreationFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatInt(prevPoolCreationFee),
		"newFee", formatInt(poolCreationFee),
	)
}

// SetWithdrawalFee sets the withdrawal fee.
// Only admin or governance can call this function.
func (p *poolV1) SetWithdrawalFeeBPS(
	withdrawalFeeBPS uint64,
) {
	halt.AssertIsNotHaltedPool()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	prevWithdrawalFee := p.store.GetWithdrawalFeeBPS()

	err := p.store.SetWithdrawalFeeBPS(withdrawalFeeBPS)
	if err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetWithdrawalFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"prevFee", formatUint(prevWithdrawalFee),
		"newFee", formatUint(withdrawalFeeBPS),
	)
}
