package grc20wrapper

import (
	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

func init() {
	pRegistry.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/bar", BarTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/bar", BarTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/bar", BarTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/baz", BazTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/baz", BazTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/baz", BazTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/foo", FooTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/foo", FooTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/foo", FooTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/gns", GnsTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/gns", GnsTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/gns", GnsTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/obl", OblTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/obl", OblTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/obl", OblTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/qux", QuxTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/qux", QuxTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/qux", QuxTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/st1", SwapTest1TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/st1", SwapTest1TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/st1", SwapTest1TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/st2", SwapTest2TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/st2", SwapTest2TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/st2", SwapTest2TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/st3", SwapTest3TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/st3", SwapTest3TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/st3", SwapTest3TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/st4", SwapTest4TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/st4", SwapTest4TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/st4", SwapTest4TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/st5", SwapTest5TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/st5", SwapTest5TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/st5", SwapTest5TokenCTokenInterface{})

	// TO BE USED
	// pRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokena", TestTokenATokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokena", TestTokenATokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokena", TestTokenATokenInterface{})

	// pRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenb", TestTokenBTokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenb", TestTokenBTokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenb", TestTokenBTokenInterface{})

	// pRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenc", TestTokenCTokenInterface{})
	// rRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenc", TestTokenCTokenInterface{})
	// sRegistry.RegisterGRC20Interface("gno.land/r/demo/testtokenc", TestTokenCTokenInterface{})
}
