package rbac

import "std"

// IsOwner checks if address is current owner.
func IsOwner(addr std.Address) bool {
	return manager.Owner() == addr
}

// IsPendingOwner checks if address is pending owner.
func IsPendingOwner(addr std.Address) bool {
	return manager.PendingOwner() == addr
}

// GetOwner returns current owner address.
func GetOwner() std.Address {
	return manager.Owner()
}

// GetPendingOwner returns pending owner address.
func GetPendingOwner() std.Address {
	return manager.PendingOwner()
}

// AcceptOwnership completes ownership transfer.
// Only callable by pending owner.
func AcceptOwnership(cur realm) {
	err := manager.AcceptOwnership()
	if err != nil {
		panic(err)
	}
}

// TransferOwnership initiates ownership transfer.
// Only callable by current owner.
func TransferOwnership(cur realm, addr std.Address) {
	err := manager.TransferOwnership(addr)
	if err != nil {
		panic(err)
	}
}
