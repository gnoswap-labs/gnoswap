package rbac

import "std"

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
