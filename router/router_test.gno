package router

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v1/consts"

	pl "gno.land/r/gnoswap/v1/pool"
)

func setupTestPool(
	t *testing.T,
	token0Path, token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	pl.SetPoolCreationFeeByAdmin(1)

	if token0Path > token1Path {
		t.Fatalf("tokens are not sorted: %s > %s", token0Path, token1Path)
	}

	pl.CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}
