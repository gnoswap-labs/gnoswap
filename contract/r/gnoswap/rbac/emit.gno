package rbac

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// emitRegisterRoleEvent emits a RegisterRole event with roleName and address information.
func emitRegisterRoleEvent(roleName string, version int, roleAddress std.Address) {
	versionStr := ufmt.Sprintf("%d", version)

	prevRealm := std.PreviousRealm()
	std.Emit(
		"RegisterRole",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleVersion", versionStr,
		"roleAddress", roleAddress.String(),
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
func emitUpdateRoleAddressEvent(roleName string, version int, address std.Address) {
	versionStr := ufmt.Sprintf("%d", version)

	prevRealm := std.PreviousRealm()
	std.Emit(
		"UpdateRoleAddress",
		"prevAddr", prevRealm.Address().String(),
		"prevRealm", prevRealm.PkgPath(),
		"roleName", roleName,
		"roleVersion", versionStr,
		"roleAddress", address.String(),
	)
}
