package rbac

import "chain/runtime"

// IsOwner returns true if addr is the current owner.
func IsOwner(addr address) bool {
	return manager.Owner() == addr
}

// IsPendingOwner returns true if addr is the pending owner.
func IsPendingOwner(addr address) bool {
	return manager.PendingOwner() == addr
}

// GetOwner returns the current owner address.
func GetOwner() address {
	return manager.Owner()
}

// GetPendingOwner returns the pending owner address.
func GetPendingOwner() address {
	return manager.PendingOwner()
}

// AcceptOwnership completes the ownership transfer process.
// Only callable by pending owner.
func AcceptOwnership(cur realm) {
	caller := runtime.PreviousRealm().Address()
	assertIsPendingOwner(caller)

	err := manager.AcceptOwnershipBy(caller)
	if err != nil {
		panic(err)
	}
}

// TransferOwnership initiates the ownership transfer process.
//
// Parameters:
//   - addr: address to transfer ownership to
//
// Only callable by current owner.
func TransferOwnership(cur realm, addr address) {
	caller := runtime.PreviousRealm().Address()
	assertIsOwner(caller)
	assertIsValidAddress(addr)

	err := manager.TransferOwnershipBy(addr, caller)
	if err != nil {
		panic(err)
	}
}
