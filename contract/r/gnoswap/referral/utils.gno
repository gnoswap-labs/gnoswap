package referral

import (
	"std"

	"gno.land/p/nt/ufmt"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

// validCallerRoles is a list of roles that are authorized to modify referral data.
// This includes governance contracts, router, position manager, and staker contracts.
var validCallerRoles = []string{
	prabc.ROLE_GOVERNANCE.String(),
	prabc.ROLE_GOV_STAKER.String(),
	prabc.ROLE_ROUTER.String(),
	prabc.ROLE_POSITION.String(),
	prabc.ROLE_STAKER.String(),
	prabc.ROLE_LAUNCHPAD.String(),
}

// isValidCaller checks if the caller address has permission to modify referral data.
// Only addresses with specific roles defined in validCallerRoles are authorized.
// Returns an error if the caller is not authorized.
func isValidCaller(caller std.Address) error {
	roleAddresses := access.GetRoleAddresses()

	for _, role := range validCallerRoles {
		if roleAddresses[role] == caller {
			return nil
		}
	}

	return ufmt.Errorf("unauthorized caller: %s", caller)
}
