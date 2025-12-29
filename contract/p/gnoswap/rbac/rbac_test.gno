package rbac

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

var (
	adminRole  = "admin"
	editorRole = "editor"

	adminAddr  = testutils.TestAddress(adminRole)
	userAddr   = testutils.TestAddress("user")
	editorAddr = testutils.TestAddress(editorRole)
)

func adminChecker(caller address) error {
	if caller != adminAddr {
		return ufmt.Errorf("caller is not admin")
	}
	return nil
}

func editorChecker(caller address) error {
	if caller != editorAddr {
		return ufmt.Errorf("caller is not editor")
	}
	return nil
}

func TestRbac_New(t *testing.T) {
	manager := New()

	uassert.NotNil(t, manager)
	uassert.NotNil(t, manager.ownable)
	uassert.NotNil(t, manager.roles)
}

func TestRbac_NewRBACWithAddress(t *testing.T) {
	tests := []struct {
		name string
		addr address
	}{
		{
			name: "Create RBAC with admin address",
			addr: adminAddr,
		},
		{
			name: "Create RBAC with user address",
			addr: userAddr,
		},
		{
			name: "Create RBAC with empty address",
			addr: address(""),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := NewRBACWithAddress(tt.addr)

			uassert.NotNil(t, manager)
			uassert.NotNil(t, manager.ownable)
			uassert.NotNil(t, manager.roles)
			uassert.Equal(t, manager.Owner(), tt.addr)
		})
	}
}

func TestRbac_RegisterRole(t *testing.T) {
	tests := []struct {
		name        string
		roleName    string
		addr        address
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "Register new role successfully",
			roleName:    adminRole,
			addr:        adminAddr,
			shouldError: false,
		},
		{
			name:        "Register another role successfully",
			roleName:    editorRole,
			addr:        editorAddr,
			shouldError: false,
		},
		{
			name:        "Register role with empty address",
			roleName:    "empty_role",
			addr:        address(""),
			shouldError: false, // RegisterRole doesn't validate address
		},
		{
			name:        "Register role with empty name fails",
			roleName:    "",
			addr:        adminAddr,
			shouldError: true,
			errorMsg:    ErrInvalidRoleName.Error(),
		},
		{
			name:        "Register role with whitespace-only name fails",
			roleName:    "   ",
			addr:        adminAddr,
			shouldError: true,
			errorMsg:    ErrInvalidRoleName.Error(),
		},
		{
			name:        "Register role with tab and space fails",
			roleName:    " \t ",
			addr:        adminAddr,
			shouldError: true,
			errorMsg:    ErrInvalidRoleName.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := New()

			err := manager.RegisterRole(tt.roleName, tt.addr)

			if tt.shouldError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.ErrorContains(t, err, tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)

				// Verify role was registered
				role, exists := manager.roles[tt.roleName]
				uassert.True(t, exists)
				uassert.Equal(t, role.Name(), tt.roleName)
				uassert.Equal(t, role.Address(), tt.addr)
			}
		})
	}
}

func TestRbac_RegisterRoleDuplicate(t *testing.T) {
	manager := New()

	err := manager.RegisterRole(adminRole, adminAddr)
	uassert.NoError(t, err)

	// Try to register same role again
	err = manager.RegisterRole(adminRole, adminAddr)
	uassert.Error(t, err)
	uassert.ErrorContains(t, err, ErrRoleAlreadyExists.Error())
}

func TestRbac_IsAuthorized(t *testing.T) {
	manager := New()

	// Register admin role
	err := manager.RegisterRole(adminRole, adminAddr)
	uassert.NoError(t, err)

	tests := []struct {
		name     string
		roleName string
		addr     address
		expected bool
	}{
		{
			name:     "Authorized address returns true",
			roleName: adminRole,
			addr:     adminAddr,
			expected: true,
		},
		{
			name:     "Unauthorized address returns false",
			roleName: adminRole,
			addr:     userAddr,
			expected: false,
		},
		{
			name:     "Non-existent role returns false",
			roleName: "non_existent",
			addr:     adminAddr,
			expected: false,
		},
		{
			name:     "Empty address returns false",
			roleName: adminRole,
			addr:     address(""),
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := manager.IsAuthorized(tt.roleName, tt.addr)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestRbac_UpdateRoleAddress(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(*RBAC)
		roleName    string
		newAddr     address
		shouldError bool
		errorMsg    string
	}{
		{
			name: "Update existing role address successfully",
			setup: func(rb *RBAC) {
				rb.RegisterRole(adminRole, adminAddr)
			},
			roleName:    adminRole,
			newAddr:     userAddr,
			shouldError: false,
		},
		{
			name:        "Update non-existent role fails",
			setup:       func(rb *RBAC) {},
			roleName:    "non_existent",
			newAddr:     userAddr,
			shouldError: true,
			errorMsg:    ErrRoleDoesNotExist.Error(),
		},
		{
			name: "Update with empty address fails",
			setup: func(rb *RBAC) {
				rb.RegisterRole(adminRole, adminAddr)
			},
			roleName:    adminRole,
			newAddr:     address(""),
			shouldError: true,
			errorMsg:    ErrInvalidAddress.Error(),
		},
		{
			name: "Update with invalid address fails",
			setup: func(rb *RBAC) {
				rb.RegisterRole(adminRole, adminAddr)
			},
			roleName:    adminRole,
			newAddr:     address("invalid"),
			shouldError: true,
			errorMsg:    ErrInvalidAddress.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager := New()
			tt.setup(manager)

			err := manager.UpdateRoleAddress(tt.roleName, tt.newAddr)

			if tt.shouldError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.ErrorContains(t, err, tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)

				// Verify address was updated
				role, exists := manager.roles[tt.roleName]
				uassert.True(t, exists)
				uassert.Equal(t, role.Address(), tt.newAddr)
			}
		})
	}
}

func TestRbac_RemoveRole(t *testing.T) {
	t.Run("success remove non-system role", func(t *testing.T) {
		manager := New()
		// First register role
		err := manager.RegisterRole(editorRole, editorAddr)
		uassert.NoError(t, err)

		// Remove role
		err = manager.RemoveRole(editorRole)
		uassert.NoError(t, err)

		// Verify role was removed
		_, exists := manager.roles[editorRole]
		uassert.False(t, exists)
	})

	t.Run("fail to remove non-existent role", func(t *testing.T) {
		manager := New()
		err := manager.RemoveRole("non_existent_role")
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, ErrRoleDoesNotExist.Error())
	})

	t.Run("fail to remove system role", func(t *testing.T) {
		manager := New()
		// Register system role
		err := manager.RegisterRole(adminRole, adminAddr)
		uassert.NoError(t, err)

		// Try to remove system role
		err = manager.RemoveRole(adminRole)
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, ErrCannotRemoveSystemRole.Error())
	})

	t.Run("remove role twice fails", func(t *testing.T) {
		manager := New()
		// Register and remove once
		err := manager.RegisterRole(editorRole, editorAddr)
		uassert.NoError(t, err)
		err = manager.RemoveRole(editorRole)
		uassert.NoError(t, err)

		// Try to remove again
		err = manager.RemoveRole(editorRole)
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, ErrRoleDoesNotExist.Error())
	})
}

func TestRbac_GetAllRoleAddresses(t *testing.T) {
	manager := New()

	t.Run("empty roles returns empty map", func(t *testing.T) {
		addresses := manager.GetAllRoleAddresses()
		uassert.NotNil(t, addresses)
		uassert.Equal(t, len(addresses), 0)
	})

	t.Run("returns all registered roles", func(t *testing.T) {
		// Register multiple roles
		err := manager.RegisterRole(adminRole, adminAddr)
		uassert.NoError(t, err)
		err = manager.RegisterRole(editorRole, editorAddr)
		uassert.NoError(t, err)

		addresses := manager.GetAllRoleAddresses()
		uassert.Equal(t, len(addresses), 2)
		uassert.Equal(t, addresses[adminRole], adminAddr)
		uassert.Equal(t, addresses[editorRole], editorAddr)
	})
}

func TestRbac_GetRoleAddress(t *testing.T) {
	manager := New()
	err := manager.RegisterRole(adminRole, adminAddr)
	uassert.NoError(t, err)

	tests := []struct {
		name        string
		roleName    string
		shouldError bool
		expectedAddr address
	}{
		{
			name:         "Get existing role address",
			roleName:     adminRole,
			shouldError:  false,
			expectedAddr: adminAddr,
		},
		{
			name:        "Get non-existent role fails",
			roleName:    "non_existent",
			shouldError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, err := manager.GetRoleAddress(tt.roleName)

			if tt.shouldError {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, ErrRoleDoesNotExist.Error())
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, addr, tt.expectedAddr)
			}
		})
	}
}

func TestRbac_OwnershipIntegration(t *testing.T) {
	manager := NewRBACWithAddress(alice)

	t.Run("Owner returns correct address", func(t *testing.T) {
		owner := manager.Owner()
		uassert.Equal(t, owner, alice)
	})

	t.Run("PendingOwner initially empty", func(t *testing.T) {
		pendingOwner := manager.PendingOwner()
		uassert.Equal(t, pendingOwner.String(), "")
	})

	t.Run("TransferOwnership sets pending owner", func(t *testing.T) {
		err := manager.TransferOwnershipBy(bob, alice)
		uassert.NoError(t, err)

		pendingOwner := manager.PendingOwner()
		uassert.Equal(t, pendingOwner, bob)

		// Owner should not change yet
		owner := manager.Owner()
		uassert.Equal(t, owner, alice)
	})

	t.Run("AcceptOwnership completes transfer", func(t *testing.T) {
		err := manager.AcceptOwnershipBy(bob)
		uassert.NoError(t, err)

		owner := manager.Owner()
		uassert.Equal(t, owner, bob)

		pendingOwner := manager.PendingOwner()
		uassert.Equal(t, pendingOwner.String(), "")
	})
}

func TestRbac_DropOwnership(t *testing.T) {
	manager := NewRBACWithAddress(alice)

	err := manager.DropOwnershipBy(alice)
	uassert.NoError(t, err)

	owner := manager.Owner()
	uassert.Equal(t, owner.String(), "")
}

func TestRbac_existsRole(t *testing.T) {
	manager := New()

	// Initially role doesn't exist
	exists := manager.existsRole(adminRole)
	uassert.False(t, exists)

	// Register role
	err := manager.RegisterRole(adminRole, adminAddr)
	uassert.NoError(t, err)

	// Now role exists
	exists = manager.existsRole(adminRole)
	uassert.True(t, exists)

	// Remove role
	manager.roles[adminRole] = nil
	delete(manager.roles, adminRole)

	// Role doesn't exist again
	exists = manager.existsRole(adminRole)
	uassert.False(t, exists)
}
