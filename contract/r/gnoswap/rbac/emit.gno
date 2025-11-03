package rbac

import (
	"chain"
	"chain/runtime"
)

// emitRegisterRoleEvent emits a RegisterRole event with roleName and address information.
func emitRegisterRoleEvent(roleName string, roleAddress address) {
	prevRealm := runtime.PreviousRealm()
	chain.Emit(
		"RegisterRole",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", roleAddress.String(),
	)
}

// emitRemoveRoleEvent emits a RemoveRole event with roleName information.
func emitRemoveRoleEvent(roleName string) {
	prevRealm := runtime.PreviousRealm()
	chain.Emit(
		"RemoveRole",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", "",
	)
}

// emitUpdateRoleAddressEvent emits an UpdateRoleAddress event with roleName and address information.
func emitUpdateRoleAddressEvent(roleName string, address address) {
	prevRealm := runtime.PreviousRealm()
	chain.Emit(
		"UpdateRoleAddress",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", address.String(),
	)
}
