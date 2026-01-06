package referral

import (
	"chain/runtime"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func setupUnitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupCaller(caller string) func() {
	origCaller := runtime.OriginCaller()
	switch caller {
	case "router":
		routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
		testing.SetOriginCaller(routerAddr)
	case "unauthorized":
		testing.SetOriginCaller(address("unauthorized"))
	}
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func cleanupGlobal() func() {
	origKeeper := gReferralKeeper
	gReferralKeeper = NewKeeper()
	return func() {
		gReferralKeeper = origKeeper
	}
}
