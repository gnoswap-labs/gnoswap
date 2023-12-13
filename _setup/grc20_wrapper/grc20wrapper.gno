package grc20wrapper

import (
	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

func init() {
	pRegistry.RegisterGRC20Interface("gno.land/r/wugnot", WugnotTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/wugnot", WugnotTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/wugnot", WugnotTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/bar", BarTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/bar", BarTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/bar", BarTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/baz", BazTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/baz", BazTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/baz", BazTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/foo", FooTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/foo", FooTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/foo", FooTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/qux", QuxTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/qux", QuxTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/qux", QuxTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st1", SwapTest1TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st1", SwapTest1TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st1", SwapTest1TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st2", SwapTest2TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st2", SwapTest2TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st2", SwapTest2TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st3", SwapTest3TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st3", SwapTest3TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st3", SwapTest3TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st4", SwapTest4TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st4", SwapTest4TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st4", SwapTest4TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st5", SwapTest5TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st5", SwapTest5TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st5", SwapTest5TokenCTokenInterface{})

	// TO BE USED
	// pRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})

	// pRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})

	// pRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
}
