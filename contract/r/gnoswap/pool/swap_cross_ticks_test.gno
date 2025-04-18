package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
)

// Test scenario:
// 1. Create a pool with positions across all ticks (-887272 to 0)
//   - Each position has range [tick, tick+887272]
//   - Each position has 1,000,000 tokens of liquidity
//
// 2. Execute a swap with following parameters:
//   - Swap token0 (bar) for token1 (baz)
//   - Fee tier: 0.01% (100)
//   - Amount: 4,000,000,000,000 token0
//   - Price limit: Maximum possible (no limit)
//   - Direction: zeroForOne (token0 to token1)
//
// 3. Verify swap results:
//   - Pool liquidity changes
//   - Fee accumulation on crossed ticks
//   - Claimable fees for each position
func TestSwapCrossTicksWithAllTicksPositions(t *testing.T) {
	addr := routerAddr

	ufmt.Println("Running tests...")

	p := createPoolWithAllTicksPositions(t)

	testing.SetOriginCaller(addr)
	Swap(
		barPath,               // token0Path
		bazPath,               // token1Path
		FeeTier100,            // fee
		adminAddr,             // recipient
		true,                  // zeroForOne
		"4000000000000",       // amountSpecified
		"9223372036854775807", // sqrtPriceLimitX96
		addr,                  // payer, router
	)

	// check the liquidity of the pool
	// check fee growth of the pool's ticks
	// check claimable fees of each position
}

// createPoolWithAllTicksPositions creates a new pool and initializes it with positions across all ticks
// Creates a pool at tick -887272 and initializes positions starting from that tick
func createPoolWithAllTicksPositions(t *testing.T) *Pool {
	t.Helper()

	testing.SetRealm(std.NewUserRealm(adminAddr))
	testing.SetOriginCaller(adminAddr)

	tick := int32(-887272)
	token0Path := barPath
	token1Path := bazPath

	SetPoolCreationFeeByAdmin(0)

	TokenApprove(t, token0Path, adminAddr, poolAddr, uint64(100_000_000_000_000))
	TokenApprove(t, token1Path, adminAddr, poolAddr, uint64(100_000_000_000_000))

	CreatePool(token0Path, token1Path, FeeTier100, "4295128740")
	createAllTicksPositions(t, token0Path, token1Path, FeeTier100, adminAddr)

	return GetPool(token0Path, token1Path, FeeTier100)
}

// createAllTicksPositions creates liquidity positions across the entire possible tick range
// For each tick from -887272 to 0:
//   - Creates a position with tick range [i, i+887272]
//   - Amount of token0 and token1 is 1000000 for each position
func createAllTicksPositions(
	t *testing.T,
	token0Path string,
	token1Path string,
	fee uint32,
	caller std.Address,
) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(caller))
	testing.SetOriginCaller(caller)

	for i := -887272; i <= 0; i++ {
		ufmt.Printf("minting position %d ~ %d\n", i, i+887272)

		MintPosition(
			t,
			token0Path,
			token1Path,
			FeeTier100,
			int32(i),
			int32(i+887272),
			"1000000",
			"1000000",
			"0",
			"0",
			max_timeout,
			caller,
			caller,
		)
	}
}
