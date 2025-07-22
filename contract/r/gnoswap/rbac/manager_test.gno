package rbac

import (
	"errors"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

var (
	testCaller      = testutils.TestAddress("caller")
	wrongCaller     = testutils.TestAddress("wrong")
	testCallerRealm = std.NewUserRealm(testCaller)
)

func TestRegisterRole(t *testing.T) {
	tt := []struct {
		name          string
		caller        std.Address
		owner         std.Address
		defaultRole   string
		inputRole     string
		expectedError error
	}{
		{
			name:          "register role success",
			caller:        testCaller,
			owner:         testCaller,
			defaultRole:   "test_role",
			inputRole:     "pool",
			expectedError: nil,
		},
		{
			name:          "register role failed by wrong caller",
			caller:        wrongCaller,
			owner:         testCaller,
			defaultRole:   "test_role",
			inputRole:     "pool",
			expectedError: prbac.ErrUnauthorized,
		},
		{
			name:          "register role failed by already registered role",
			caller:        testCaller,
			owner:         testCaller,
			defaultRole:   "test_role",
			inputRole:     "test_role",
			expectedError: ufmt.Errorf("role test_role already exists"),
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			testing.SetOriginCaller(tc.caller)
			globalManager = prbac.NewRBACWithAddress(tc.owner)

			// when
			err := RegisterRole(cross, tc.inputRole)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
		})
	}
}

func TestRemoveRole(t *testing.T) {
	tt := []struct {
		name          string
		caller        std.Address
		owner         std.Address
		roleName      string
		inputRoleName string
		expectedError error
	}{
		{
			name:          "remove role success",
			caller:        testCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "test_role",
			expectedError: nil,
		},
		{
			name:          "remove role failed by wrong caller",
			caller:        wrongCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "test_role",
			expectedError: prbac.ErrUnauthorized,
		},
		{
			name:          "remove role failed by not existing role",
			caller:        testCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "wrong_role",
			expectedError: ufmt.Errorf("role wrong_role does not exist"),
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			testing.SetOriginCaller(tc.owner)
			globalManager = prbac.NewRBACWithAddress(tc.owner)

			// given - input role
			err := RegisterRole(cross, tc.roleName)
			uassert.NoError(t, err)

			// when
			testing.SetOriginCaller(tc.caller)
			err = RemoveRole(cross, tc.inputRoleName)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
		})
	}
}

func TestDeclareRole(t *testing.T) {
	tt := []struct {
		name             string
		caller           std.Address
		owner            std.Address
		roleName         string
		inputRoleName    string
		inputRoleOptions []prbac.RoleOption
		expectedError    error
	}{
		{
			name:          "declare role success",
			caller:        testCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "newAdmin",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError: nil,
		},
		{
			name:          "declare role failed by wrong caller",
			caller:        wrongCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "newAdmin",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError: prbac.ErrUnauthorized,
		},
		{
			name:          "declare role failed by already declared role",
			caller:        wrongCaller,
			owner:         testCaller,
			roleName:      "test_role",
			inputRoleName: "test_role",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError: ufmt.Errorf("role test_role already exists"),
		},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			// given
			testing.SetOriginCaller(tc.owner)
			globalManager = prbac.NewRBACWithAddress(tc.owner)

			// when
			testing.SetOriginCaller(tc.caller)
			err := DeclareRole(cross, tc.inputRoleName, tc.inputRoleOptions...)

			// then
			uassert.ErrorIs(t, err, tc.expectedError)
		})
	}
}
