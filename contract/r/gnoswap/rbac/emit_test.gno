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
		{
			name:        "Emit register role event with empty address",
			roleName:    "test_role",
			roleAddress: address(""),
		},
		{
			name:        "Emit register role event with invalid address format",
			roleName:    "test_role",
			roleAddress: address("invalid"),
		},
		{
			name:        "Emit register role event with malformed address",
			roleName:    "test_role",
			roleAddress: address("g1"),
		},
		{
			name:        "Emit register role event with special characters in role name",
			roleName:    "test@role#123",
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
		{
			name:     "Emit remove role event with special characters in role name",
			roleName: "test@role#123",
		},
		{
			name:     "Emit remove role event with very long role name",
			roleName: "very_long_role_name_that_exceeds_normal_length_expectations_for_testing_purposes",
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
		{
			name:        "Emit update role address event with empty address",
			roleName:    "test_role",
			roleAddress: address(""),
		},
		{
			name:        "Emit update role address event with invalid address format",
			roleName:    "test_role",
			roleAddress: address("invalid"),
		},
		{
			name:        "Emit update role address event with malformed address",
			roleName:    "test_role",
			roleAddress: address("g1"),
		},
		{
			name:        "Emit update role address event with special characters in role name",
			roleName:    "test@role#123",
			roleAddress: ADMIN,
		},
		{
			name:        "Emit update role address event with both empty",
			roleName:    "",
			roleAddress: address(""),
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
