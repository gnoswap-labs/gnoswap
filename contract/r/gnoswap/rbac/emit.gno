package rbac

import "std"

// emitRegisterRoleEvent emits a RegisterRole event with roleName information.
func emitRegisterRoleEvent(roleName string) {
	prevRealm := std.PreviousRealm()
	std.Emit(
		"RegisterRole",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", "",
	)
}

// emitRemoveRoleEvent emits a RemoveRole event with roleName information.
func emitRemoveRoleEvent(roleName string) {
	prevRealm := std.PreviousRealm()
	std.Emit(
		"RemoveRole",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", "",
	)
}

// emitUpdateRoleAddressEvent emits an UpdateRoleAddress event with roleName and address information.
func emitUpdateRoleAddressEvent(roleName string, address std.Address) {
	prevRealm := std.PreviousRealm()
	std.Emit(
		"UpdateRoleAddress",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleAddress", address.String(),
	)
}
