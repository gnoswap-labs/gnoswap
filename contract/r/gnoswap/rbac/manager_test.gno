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

func setupTest(t *testing.T) {
	testing.SetOriginCaller(testCaller)
	// Set the owner of globalManager to testCaller
	globalManager = prbac.NewRBACWithAddress(testCaller)
}

func TestRegisterRole(t *testing.T) {
	setupTest(t)
	err := RegisterRole(cur, "admin")
	uassert.NoError(t, err)

	// Fail: already existed role
	err = RegisterRole(cur, "admin")
	uassert.Error(t, err)
}

func TestRegisterAndCheckPermission(t *testing.T) {
	setupTest(t)
	roleName := "moderator"
	permissionName := "can_delete"

	// register role
	err := RegisterRole(cur, roleName)
	uassert.NoError(t, err)

	// register permission
	checker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errors.New("wrong caller")
	}
	err = RegisterPermission(cur, roleName, permissionName, checker)
	uassert.NoError(t, err)

	// check permission - success case
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.NoError(t, err)

	// check permission - fail case (wrong caller)
	err = CheckPermission(roleName, permissionName, wrongCaller)
	uassert.Error(t, err)
}

func TestUpdateAndRemovePermission(t *testing.T) {
	setupTest(t)
	roleName := "editor"
	permissionName := "can_edit"

	errWrongCaller := errors.New("wrong caller")

	// initial setup
	err := RegisterRole(cur, roleName)
	uassert.NoError(t, err)

	originalChecker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errWrongCaller
	}
	err = RegisterPermission(cur, roleName, permissionName, originalChecker)
	uassert.NoError(t, err)

	// update permission
	newChecker := func(addr std.Address) error {
		return errWrongCaller
	}
	err = UpdatePermission(cur, roleName, permissionName, newChecker)
	uassert.NoError(t, err)

	// check updated permission
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.Error(t, err)

	// remove permission
	err = RemovePermission(cur, roleName, permissionName)
	uassert.NoError(t, err)

	// check removed permission
	err = CheckPermission(roleName, permissionName, testCaller)
	uassert.Error(t, err)
}

func TestDeclareRole(t *testing.T) {
	roleName := "supervisor"
	permissionName := "can_supervise"

	errWrongCaller := errors.New("wrong caller")

	checker := func(addr std.Address) error {
		if addr == testCaller {
			return nil
		}
		return errWrongCaller
	}

	err := DeclareRole(cur, roleName,
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
		err := RegisterRole(nil, roleName)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("RegisterPermission unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RegisterPermission(nil, roleName, permissionName, checker)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})

	t.Run("RemovePermission unauthorized", func(t *testing.T) {
		testing.SetOriginCaller(wrongCaller)
		err := RemovePermission(nil, roleName, permissionName)
		uassert.ErrorContains(t, err, prbac.ErrUnauthorized.Error())
	})
}
