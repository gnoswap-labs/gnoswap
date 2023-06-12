package position

import (
	"crypto/sha256"
	"encoding/hex"
	"std"

	"gno.land/p/demo/ufmt"
)

const POOL_INIT_CODE_HASH bigint = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54

type PoolKey struct {
	token0 std.Address
	token1 std.Address
	fee    bigint
}

func PoolAddressGetPoolKey(
	tokenA std.Address,
	tokenB std.Address,
	fee bigint,
) PoolKey {
	// XXX can we sort std.Address ???
	if tokenA.String() > tokenB.String() {
		tokenA, tokenB = tokenB, tokenA
	}

	return PoolKey{
		token0: tokenA,
		token1: tokenB,
		fee:    fee,
	}
}

func PoolAddressComputeAddress(
	factory std.Address,
	poolKey PoolKey,
) string { // std.Address ??
	inner_key := ufmt.Sprintf("%s__%s__%d", poolKey.token0.String(), poolKey.token1.String(), poolKey.fee)
	inner_sum := sha256.Sum256([]byte(inner_key))[:]
	inner_hex := hex.EncodeToString([]byte(inner_sum))

	outer_key := ufmt.Sprintf("ff__%s__%s__%d", factory.String(), inner_hex, POOL_INIT_CODE_HASH)
	outer_sum := sha256.Sum256([]byte(outer_key))[:]
	outer_hex := hex.EncodeToString([]byte(outer_sum))

	return outer_hex
}
