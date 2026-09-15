package rbac

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

// IsOwner reports whether addr is the current owner address.
//
// Parameters:
//   - addr: address to compare with the configured owner
//
// Returns:
//   - owner: true when addr equals the current owner; false otherwise
func IsOwner(addr address) bool {
	return manager.Owner() == addr
}

// IsPendingOwner reports whether addr is the address awaiting ownership acceptance.
//
// Parameters:
//   - addr: address to compare with the configured pending owner
//
// Returns:
//   - pending: true when addr equals the pending owner; false otherwise
func IsPendingOwner(addr address) bool {
	return manager.PendingOwner() == addr
}

// GetOwner returns the currently configured owner address.
//
// Returns:
//   - owner: current owner address
func GetOwner() address {
	return manager.Owner()
}

// GetPendingOwner returns the address awaiting ownership acceptance.
//
// Returns:
//   - pendingOwner: pending owner address, or the zero address when no transfer is pending
func GetPendingOwner() address {
	return manager.PendingOwner()
}

// AcceptOwnership completes a pending ownership transfer and synchronizes the
// admin role with the new owner.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//
// Only callable by the pending owner.
func AcceptOwnership(cur realm) {
	caller := cur.Previous().Address()
	assertIsPendingOwner(caller)

	err := manager.AcceptOwnershipBy(caller)
	if err != nil {
		panic(err)
	}

	newOwner := manager.Owner()
	err = manager.UpdateRoleAddress(prbac.ROLE_ADMIN.String(), newOwner)
	if err != nil {
		panic(makeErrorWithDetails(
			err.Error(),
			ufmt.Sprintf(
				"role name: %s, address: %s",
				prbac.ROLE_ADMIN.String(), newOwner.String()),
		))
	}
	access.SetRoleAddress(cross(cur), prbac.ROLE_ADMIN.String(), newOwner)
}

// TransferOwnership starts a two-step ownership transfer to addr.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - addr: valid address that will become pending owner and may later accept ownership
//
// Only callable by the current owner.
func TransferOwnership(cur realm, addr address) {
	caller := cur.Previous().Address()
	assertIsOwner(caller)
	assertIsValidAddress(addr)

	err := manager.TransferOwnershipBy(addr, caller)
	if err != nil {
		panic(err)
	}
}
