package access

import (
	"std"
)

// EmitAddressRegistered emits an event when a new address is registered
func EmitAddressRegistered(role string, addr std.Address, path string) {
	std.Emit(
		EventAddressRegistered,
		"role", role,
		"address", addr.String(),
		"path", path,
	)
}

// EmitAddressUpdated emits an event when an address is updated
func EmitAddressUpdated(role string, oldAddr, newAddr std.Address, path string) {
	std.Emit(
		EventAddressUpdated,
		"role", role,
		"oldAddress", oldAddr.String(),
		"newAddress", newAddr.String(),
		"path", path,
	)
}
