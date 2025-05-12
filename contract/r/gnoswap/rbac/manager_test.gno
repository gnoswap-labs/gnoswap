package rbac

import (
	"errors"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
)

var (
	testCaller  = testutils.TestAddress("caller")
	wrongCaller = testutils.TestAddress("wrong")
)

func TestRegisterRole(t *testing.T) {
	err := RegisterRole("admin")
	uassert.NoError(t, err)

	// Fail: already existed role
	err = RegisterRole("admin")
	uassert.Error(t, err)
}

func TestRegisterAndCheckPermission(t *testing.T) {
	roleName := "moderator"
	permissionName := "can_delete"

	// register role
	err := RegisterRole(roleName)
	uassert.NoError(t, err)

	// register permission
	checker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errors.New("wrong caller")
	}
	err = RegisterPermission(roleName, permissionName, checker)
	uassert.NoError(t, err)

	// check permission - success case
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.NoError(t, err)

	// check permission - fail case (wrong caller)
	err = CheckPermission(roleName, permissionName, wrongCaller)
	uassert.Error(t, err)
}

func TestUpdateAndRemovePermission(t *testing.T) {
	roleName := "editor"
	permissionName := "can_edit"

	var errWrongCaller = errors.New("wrong caller")

	// initial setup
	RegisterRole(roleName)
	originalChecker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errWrongCaller
	}
	RegisterPermission(roleName, permissionName, originalChecker)

	// update permission
	newChecker := func(addr std.Address) error {
		return errWrongCaller
	}
	err := UpdatePermission(roleName, permissionName, newChecker)
	uassert.NoError(t, err)

	// check updated permission
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.Error(t, err)

	// remove permission
	err = RemovePermission(roleName, permissionName)
	uassert.NoError(t, err)

	// check removed permission
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.Error(t, err)
}

func TestDeclareRole(t *testing.T) {
	roleName := "supervisor"
	permissionName := "can_supervise"

	var errWrongCaller = errors.New("wrong caller")

	checker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errWrongCaller
	}

	err := DeclareRole(roleName,
		prbac.WithPermission(permissionName, checker))
	uassert.NoError(t, err)

	// check permission
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.NoError(t, err)
}

func TestUnauthorizedAccess(t *testing.T) {
	roleName := "test_role"
	permissionName := "test_permission"
	checker := func(addr std.Address) error { return nil }

	t.Run("RegisterRole unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RegisterRole(roleName)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("RegisterPermission unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RegisterPermission(roleName, permissionName, checker)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("UpdatePermission unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := UpdatePermission(roleName, permissionName, checker)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("RemovePermission unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RemovePermission(roleName, permissionName)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("RemoveRole unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RemoveRole(roleName)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("DeclareRole unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := DeclareRole(roleName, prbac.WithPermission(permissionName, checker))
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("CheckPermission still accessible", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := CheckPermission(roleName, permissionName, testCaller)
		uassert.Error(t, err) // Should fail for non-existent role/permission, but not due to authorization
	})
}
