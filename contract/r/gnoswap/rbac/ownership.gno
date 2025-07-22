package rbac

import "std"

// IsOwner checks if the given address is the current owner of the contract.
// This function compares the provided address with the stored owner address.
// Returns true if the addresses match, false otherwise.
func IsOwner(addr std.Address) bool {
	return manager.Owner() == addr
}

// IsPendingOwner verifies if the given address is set as the pending owner.
// This is used in the two-step ownership transfer process to validate the pending owner.
// Returns true if the address matches the pending owner, false otherwise.
func IsPendingOwner(addr std.Address) bool {
	return manager.PendingOwner() == addr
}

// GetOwner retrieves the current owner's address from the contract.
// This function provides read-only access to the owner information.
// Returns the address of the current contract owner.
func GetOwner() std.Address {
	return manager.Owner()
}

// GetPendingOwner retrieves the address of the pending owner.
// This is used to check the status of an ongoing ownership transfer.
// Returns the address of the pending owner, or empty if no transfer is in progress.
func GetPendingOwner() std.Address {
	return manager.PendingOwner()
}

// AcceptOwnership completes the ownership transfer process.
// This function can only be called by the pending owner to accept their new role.
// Panics if called by any address other than the pending owner or if the transfer fails.
func AcceptOwnership(cur realm) {
	assertIsPendingOwner(std.PreviousRealm().Address())

	err := manager.AcceptOwnership()
	if err != nil {
		panic(err)
	}
}

// TransferOwnership initiates the transfer of ownership to a new address.
// Only the current owner can initiate this transfer, setting up the two-step ownership transfer process.
// Panics if called by non-owner or if the transfer initiation fails.
func TransferOwnership(cur realm, addr std.Address) {
	assertIsOwner(std.PreviousRealm().Address())

	err := manager.TransferOwnership(addr)
	if err != nil {
		panic(err)
	}
}
