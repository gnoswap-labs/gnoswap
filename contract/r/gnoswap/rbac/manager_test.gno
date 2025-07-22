package rbac

import (
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
			name:             "declare role success",
			caller:           testCaller,
			owner:            testCaller,
			roleName:         "test_role",
			inputRoleName:    "newAdmin",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError:    nil,
		},
		{
			name:             "declare role failed by wrong caller",
			caller:           wrongCaller,
			owner:            testCaller,
			roleName:         "test_role",
			inputRoleName:    "newAdmin",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError:    prbac.ErrUnauthorized,
		},
		{
			name:             "declare role failed by already declared role",
			caller:           wrongCaller,
			owner:            testCaller,
			roleName:         "test_role",
			inputRoleName:    "test_role",
			inputRoleOptions: []prbac.RoleOption{},
			expectedError:    ufmt.Errorf("role test_role already exists"),
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

func TestManager_GlobalManager(t *testing.T) {
	tests := []struct {
		name             string
		setupOwner       std.Address
		expectedNotNil   bool
		expectedOwner    std.Address
		expectedHasPanic bool
		expectedPanicMsg string
	}{
		{
			name:             "success - get global manager",
			setupOwner:       testutils.TestAddress("owner1"),
			expectedNotNil:   true,
			expectedOwner:    testutils.TestAddress("owner1"),
			expectedHasPanic: false,
		},
		{
			name:             "success - get global manager with different owner",
			setupOwner:       testutils.TestAddress("owner2"),
			expectedNotNil:   true,
			expectedOwner:    testutils.TestAddress("owner2"),
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMsg, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanup()

			// given
			testing.SetOriginCaller(tc.setupOwner)
			globalManager = prbac.NewRBACWithAddress(tc.setupOwner)

			// when
			manager := GlobalManager()

			// then
			if tc.expectedNotNil {
				uassert.NotNil(t, manager)
				uassert.Equal(t, tc.expectedOwner, manager.Owner())
			} else {
				uassert.Nil(t, manager)
			}
		})
	}
}

func TestManager_OwnershipValidation(t *testing.T) {
	tests := []struct {
		name             string
		setupOwner       std.Address
		caller           std.Address
		roleName         string
		expectedHasPanic bool
		expectedPanicMsg string
		expectedError    error
	}{
		{
			name:             "success - owner can register role",
			setupOwner:       testutils.TestAddress("owner1"),
			caller:           testutils.TestAddress("owner1"),
			roleName:         "test_role",
			expectedHasPanic: false,
			expectedError:    nil,
		},
		{
			name:             "fail - non-owner cannot register role",
			setupOwner:       testutils.TestAddress("owner1"),
			caller:           testutils.TestAddress("notowner"),
			roleName:         "test_role",
			expectedHasPanic: false,
			expectedError:    prbac.ErrUnauthorized,
		},
		{
			name:             "success - different owner can register role",
			setupOwner:       testutils.TestAddress("owner2"),
			caller:           testutils.TestAddress("owner2"),
			roleName:         "admin_role",
			expectedHasPanic: false,
			expectedError:    nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMsg, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanup()

			// given
			testing.SetOriginCaller(tc.setupOwner)
			globalManager = prbac.NewRBACWithAddress(tc.setupOwner)

			// when
			testing.SetOriginCaller(tc.caller)
			err := RegisterRole(cross, tc.roleName)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestManager_RegisterRoleExtended(t *testing.T) {
	tests := []struct {
		name             string
		setupOwner       std.Address
		caller           std.Address
		roleName         string
		expectedHasPanic bool
		expectedPanicMsg string
		expectedError    error
	}{
		{
			name:             "success - register admin role",
			setupOwner:       testutils.TestAddress("admin"),
			caller:           testutils.TestAddress("admin"),
			roleName:         "admin",
			expectedHasPanic: false,
			expectedError:    nil,
		},
		{
			name:             "success - register custom role",
			setupOwner:       testutils.TestAddress("admin"),
			caller:           testutils.TestAddress("admin"),
			roleName:         "custom_role",
			expectedHasPanic: false,
			expectedError:    nil,
		},
		{
			name:             "fail - unauthorized caller",
			setupOwner:       testutils.TestAddress("admin"),
			caller:           testutils.TestAddress("hacker"),
			roleName:         "hack_role",
			expectedHasPanic: false,
			expectedError:    prbac.ErrUnauthorized,
		},
		{
			name:             "fail - empty role name",
			setupOwner:       testutils.TestAddress("admin"),
			caller:           testutils.TestAddress("admin"),
			roleName:         "",
			expectedHasPanic: false,
			expectedError:    nil, // Should succeed with empty string
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMsg, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			cleanup()

			// given
			testing.SetOriginCaller(tc.setupOwner)
			globalManager = prbac.NewRBACWithAddress(tc.setupOwner)

			// when
			testing.SetOriginCaller(tc.caller)
			err := RegisterRole(cross, tc.roleName)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Helper function to cleanup global state
func cleanup() {
	globalManager = prbac.New()
}
