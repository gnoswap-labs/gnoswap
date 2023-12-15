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
}
