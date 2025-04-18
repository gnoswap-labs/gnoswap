package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
)

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
