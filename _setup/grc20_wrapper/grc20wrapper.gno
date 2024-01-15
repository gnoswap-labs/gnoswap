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

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token01", Token1TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token01", Token1TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token01", Token1TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token02", Token2TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token02", Token2TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token02", Token2TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token03", Token3TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token03", Token3TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token03", Token3TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token04", Token4TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token04", Token4TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token04", Token4TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token05", Token5TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token05", Token5TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token05", Token5TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token06", Token6TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token06", Token6TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token06", Token6TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token07", Token7TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token07", Token7TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token07", Token7TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token08", Token8TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token08", Token8TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token08", Token8TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token09", Token9TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token09", Token9TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token09", Token9TokenInterface{})

	pRegistry.RegisterGRC20Interface("gno.land/r/demo/token10", Token10TokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/demo/token10", Token10TokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/demo/token10", Token10TokenInterface{})
}
