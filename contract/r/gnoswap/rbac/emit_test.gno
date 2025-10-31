package rbac

import (
	"testing"
)

func TestEmit_emitRegisterRoleEvent(t *testing.T) {
	tests := []struct {
		name        string
		roleName    string
		roleAddress address
	}{
		{
			name:        "Emit register role event with valid params",
			roleName:    "test_role",
			roleAddress: ADMIN,
		},
		{
			name:        "Emit register role event with empty role name",
			roleName:    "",
			roleAddress: ADMIN,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup code realm context so runtime.PreviousRealm() works
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac"))

			// Should not panic - just emits event
			emitRegisterRoleEvent(tt.roleName, tt.roleAddress)
		})
	}
}

func TestEmit_emitRemoveRoleEvent(t *testing.T) {
	tests := []struct {
		name     string
		roleName string
	}{
		{
			name:     "Emit remove role event with valid role name",
			roleName: "test_role",
		},
		{
			name:     "Emit remove role event with empty role name",
			roleName: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup code realm context so runtime.PreviousRealm() works
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac"))

			// Should not panic - just emits event
			emitRemoveRoleEvent(tt.roleName)
		})
	}
}

func TestEmit_emitUpdateRoleAddressEvent(t *testing.T) {
	tests := []struct {
		name        string
		roleName    string
		roleAddress address
	}{
		{
			name:        "Emit update role address event with valid params",
			roleName:    "test_role",
			roleAddress: DEV_OPS,
		},
		{
			name:        "Emit update role address event with empty role name",
			roleName:    "",
			roleAddress: ADMIN,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup code realm context so runtime.PreviousRealm() works
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac"))

			// Should not panic - just emits event
			emitUpdateRoleAddressEvent(tt.roleName, tt.roleAddress)
		})
	}
}
