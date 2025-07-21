package halt

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"
)

// assertIsAdminOrGovernance verifies that the caller has either admin or governance privileges
// This function allows operations that require elevated permissions from either role
// Panics with a descriptive error if the caller lacks both permissions
func assertIsAdminOrGovernance(caller std.Address) {
	// Check admin permissions first
	errAccessAdmin := access.AdminOnly(caller)
	// Check governance permissions second
	errAccessGovernance := access.GovernanceOnly(caller)
	
	// If both checks fail, the caller has neither admin nor governance privileges
	if errAccessAdmin != nil && errAccessGovernance != nil {
		panic(ufmt.Errorf("caller %s is not admin or governance", caller.String()))
	}
}

// assertIsAdmin verifies that the caller has admin privileges
// This function is used for operations that specifically require admin access
// Panics if the caller is not an admin
func assertIsAdmin(caller std.Address) {
	if err := access.AdminOnly(caller); err != nil {
		panic(err)
	}
}

// assertIsGovernance verifies that the caller has governance privileges
// This function is used for operations that specifically require governance access
// Panics if the caller is not a governance entity
func assertIsGovernance(caller std.Address) {
	if err := access.GovernanceOnly(caller); err != nil {
		panic(err)
	}
}