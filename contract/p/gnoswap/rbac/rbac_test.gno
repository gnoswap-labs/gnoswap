package rbac

import (
	"std"
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

func adminChecker(caller std.Address) error {
	if caller != adminAddr {
		return ufmt.Errorf("caller is not admin")
	}
	return nil
}

func editorChecker(caller std.Address) error {
	if caller != editorAddr {
		return ufmt.Errorf("caller is not editor")
	}
	return nil
}

func TestRegisterRole(t *testing.T) {
	manager := New()

	err := manager.RegisterRole(adminRole)
	uassert.NoError(t, err)

	err = manager.RegisterRole(adminRole)
	uassert.Error(t, err)
}

func TestRemoveRole(t *testing.T) {
	manager := New()

	t.Run("success remove non-system role", func(t *testing.T) {
		// First register role and permission
		err := manager.RegisterRole(editorRole)
		uassert.NoError(t, err)

		// Remove role
		err = manager.RemoveRole(editorRole)
		uassert.NoError(t, err)
	})

	t.Run("fail to remove non-existent role", func(t *testing.T) {
		err := manager.RemoveRole("non_existent_role")
		uassert.Error(t, err)
	})

	t.Run("fail to remove system role", func(t *testing.T) {
		// Register system role
		err := manager.RegisterRole(adminRole)
		uassert.NoError(t, err)

		// Try to remove system role
		err = manager.RemoveRole(adminRole)
		uassert.Error(t, err)
	})
}
