package referral

import (
	"std"

	"gno.land/p/demo/ufmt"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
)

// validCallers is a lookup table of addresses that are authorized to modify referral data.
// This includes governance contracts, router, position manager, and staker contracts.
var validCallers = map[std.Address]bool{
	getAddress(prabc.ROLE_GOVERNANCE.String()): true,
	getAddress(prabc.ROLE_GOV_STAKER.String()): true,
	getAddress(prabc.ROLE_ROUTER.String()):     true,
	getAddress(prabc.ROLE_POSITION.String()):   true,
	getAddress(prabc.ROLE_STAKER.String()):     true,
	getAddress(prabc.ROLE_LAUNCHPAD.String()):  true,
}

// isValidCaller checks if the given address has permission to modify referral data.
// Only specific pre-authorized addresses defined in validCallers map are allowed to
// register, update, or remove referrals.
func isValidCaller(caller std.Address) error {
	if validCallers[caller] {
		return nil
	}
	return ufmt.Errorf("unauthorized caller: %s", caller)
}

func getAddress(role string) std.Address {
	addr, ok := access.GetAddress(role)
	if !ok {
		panic(ufmt.Errorf("address not found for role: %s", role))
	}
	return addr
}
