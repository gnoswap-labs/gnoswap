package rbac

import "std"

// IsOwner returns true if addr is the current owner.
func IsOwner(addr std.Address) bool {
	return manager.Owner() == addr
}

// IsPendingOwner returns true if addr is the pending owner.
func IsPendingOwner(addr std.Address) bool {
	return manager.PendingOwner() == addr
}

// GetOwner returns the current owner address.
func GetOwner() std.Address {
	return manager.Owner()
}

// GetPendingOwner returns the pending owner address.
func GetPendingOwner() std.Address {
	return manager.PendingOwner()
}

// AcceptOwnership completes the ownership transfer process.
// Only callable by pending owner.
func AcceptOwnership(cur realm) {
	err := manager.AcceptOwnership()
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
func TransferOwnership(cur realm, addr std.Address) {
	err := manager.TransferOwnership(addr)
	if err != nil {
		panic(err)
	}
}
