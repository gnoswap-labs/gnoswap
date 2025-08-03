package gns

import (
	"std"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
)

var avgBlockTimeChangeCallbacks = map[string]func(int64){}

func SetAvgBlockTimeChangeCallback(cur realm, callback func(int64)) {
	caller := std.PreviousRealm().Address()
	access.AssertHasAnyRole(
		caller,
		prabc.ROLE_STAKER.String(),
		prabc.ROLE_GOVERNANCE.String(),
		prabc.ROLE_GOV_STAKER.String(),
		prabc.ROLE_LAUNCHPAD.String(),
		prabc.ROLE_ADMIN.String(),
	)

	currentRole := ""

	roleAddresses := access.GetRoleAddresses()
	for role, addr := range roleAddresses {
		if addr == caller {
			currentRole = role
			break
		}
	}

	if currentRole == "" {
		panic(ufmt.Errorf("caller %s is not a role", caller))
	}

	avgBlockTimeChangeCallbacks[currentRole] = callback
}
