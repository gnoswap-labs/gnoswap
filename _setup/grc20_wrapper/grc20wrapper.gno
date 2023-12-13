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

	pRegistry.RegisterGRC20Interface("gno.land/r/st11", SwapTest11TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st11", SwapTest11TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st11", SwapTest11TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st22", SwapTest22TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st22", SwapTest22TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st22", SwapTest22TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st33", SwapTest33TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st33", SwapTest33TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st33", SwapTest33TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st44", SwapTest44TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st44", SwapTest44TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st44", SwapTest44TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/st55", SwapTest55TokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/st55", SwapTest55TokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/st55", SwapTest55TokenCTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/testtokena", TestTokenATokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/testtokenb", TestTokenBTokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/testtokenc", TestTokenCTokenInterface{})
}
