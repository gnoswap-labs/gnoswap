package community_pool

import (
	"testing"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/r/demo/defi/grc20reg"
)

func registerIBCVoucherToken(
	realmPath, slug, baseDenom string,
	mintTo address,
	mintAmount int64,
) {
	testing.SetRealm(testing.NewCodeRealm(realmPath))
	token, ledger := grc20.NewToken(baseDenom, slug, 0)
	if err := ledger.Mint(mintTo, mintAmount); err != nil {
		panic(err)
	}
	grc20reg.Register(cross, token, slug)
}
