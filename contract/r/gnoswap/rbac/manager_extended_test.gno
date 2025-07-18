package rbac

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestManager_GlobalManager(t *testing.T) {
	tests := []struct {
		name              string
		setupOwner        std.Address
		expectedNotNil    bool
		expectedOwner     std.Address
		expectedHasPanic  bool
		expectedPanicMsg  string
	}{
		{
			name:              "success - get global manager",
			setupOwner:        testutils.TestAddress("owner1"),
			expectedNotNil:    true,
			expectedOwner:     testutils.TestAddress("owner1"),
			expectedHasPanic:  false,
		},
		{
			name:              "success - get global manager with different owner",
			setupOwner:        testutils.TestAddress("owner2"),
			expectedNotNil:    true,
			expectedOwner:     testutils.TestAddress("owner2"),
			expectedHasPanic:  false,
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
		name                string
		setupOwner          std.Address
		caller              std.Address
		roleName            string
		expectedHasPanic    bool
		expectedPanicMsg    string
		expectedError       error
	}{
		{
			name:                "success - owner can register role",
			setupOwner:          testutils.TestAddress("owner1"),
			caller:              testutils.TestAddress("owner1"),
			roleName:            "test_role",
			expectedHasPanic:    false,
			expectedError:       nil,
		},
		{
			name:                "fail - non-owner cannot register role",
			setupOwner:          testutils.TestAddress("owner1"),
			caller:              testutils.TestAddress("notowner"),
			roleName:            "test_role",
			expectedHasPanic:    false,
			expectedError:       prbac.ErrUnauthorized,
		},
		{
			name:                "success - different owner can register role",
			setupOwner:          testutils.TestAddress("owner2"),
			caller:              testutils.TestAddress("owner2"),
			roleName:            "admin_role",
			expectedHasPanic:    false,
			expectedError:       nil,
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
		name                string
		setupOwner          std.Address
		caller              std.Address
		roleName            string
		expectedHasPanic    bool
		expectedPanicMsg    string
		expectedError       error
	}{
		{
			name:                "success - register admin role",
			setupOwner:          testutils.TestAddress("admin"),
			caller:              testutils.TestAddress("admin"),
			roleName:            "admin",
			expectedHasPanic:    false,
			expectedError:       nil,
		},
		{
			name:                "success - register custom role",
			setupOwner:          testutils.TestAddress("admin"),
			caller:              testutils.TestAddress("admin"),
			roleName:            "custom_role",
			expectedHasPanic:    false,
			expectedError:       nil,
		},
		{
			name:                "fail - unauthorized caller",
			setupOwner:          testutils.TestAddress("admin"),
			caller:              testutils.TestAddress("hacker"),
			roleName:            "hack_role",
			expectedHasPanic:    false,
			expectedError:       prbac.ErrUnauthorized,
		},
		{
			name:                "fail - empty role name",
			setupOwner:          testutils.TestAddress("admin"),
			caller:              testutils.TestAddress("admin"),
			roleName:            "",
			expectedHasPanic:    false,
			expectedError:       nil, // Should succeed with empty string
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

func TestManager_CheckPermissionExtended(t *testing.T) {
	tests := []struct {
		name                string
		setupOwner          std.Address
		setupRole           string
		setupPermission     string
		roleName            string
		permissionName      string
		caller              std.Address
		expectedHasPanic    bool
		expectedPanicMsg    string
		expectedError       error
	}{
		{
			name:                "success - valid permission check",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "admin",
			permissionName:      "manage",
			caller:              testutils.TestAddress("admin"),
			expectedHasPanic:    false,
			expectedError:       nil,
		},
		{
			name:                "fail - role does not exist",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "nonexistent",
			permissionName:      "manage",
			caller:              testutils.TestAddress("admin"),
			expectedHasPanic:    false,
			expectedError:       nil, // Will return specific error from underlying RBAC
		},
		{
			name:                "fail - permission does not exist",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "admin",
			permissionName:      "nonexistent",
			caller:              testutils.TestAddress("admin"),
			expectedHasPanic:    false,
			expectedError:       nil, // Will return specific error from underlying RBAC
		},
		{
			name:                "fail - permission check fails",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "admin",
			permissionName:      "manage",
			caller:              testutils.TestAddress("hacker"),
			expectedHasPanic:    false,
			expectedError:       nil, // Will return specific error from permission checker
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

			// Setup role and permission
			err := RegisterRole(cross, tc.setupRole)
			uassert.NoError(t, err)

			permissionChecker := func(addr std.Address) error {
				if addr == tc.setupOwner {
					return nil
				}
				return prbac.ErrUnauthorized
			}
			err = RegisterPermission(cross, tc.setupRole, tc.setupPermission, permissionChecker)
			uassert.NoError(t, err)

			// when
			err = CheckPermission(tc.roleName, tc.permissionName, tc.caller)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				// For success cases, check if error is nil
				if tc.name == "success - valid permission check" {
					uassert.NoError(t, err)
				} else {
					uassert.Error(t, err) // For other cases, expect an error
				}
			}
		})
	}
}

func TestManager_UpdatePermissionExtended(t *testing.T) {
	tests := []struct {
		name                string
		setupOwner          std.Address
		setupRole           string
		setupPermission     string
		roleName            string
		permissionName      string
		expectedHasPanic    bool
		expectedPanicMsg    string
		expectedError       error
	}{
		{
			name:                "success - update existing permission",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "admin",
			permissionName:      "manage",
			expectedHasPanic:    false,
			expectedError:       nil,
		},
		{
			name:                "fail - role does not exist",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "nonexistent",
			permissionName:      "manage",
			expectedHasPanic:    false,
			expectedError:       nil, // Will return specific error from underlying RBAC
		},
		{
			name:                "fail - permission does not exist",
			setupOwner:          testutils.TestAddress("admin"),
			setupRole:           "admin",
			setupPermission:     "manage",
			roleName:            "admin",
			permissionName:      "nonexistent",
			expectedHasPanic:    false,
			expectedError:       nil, // Will return specific error from underlying RBAC
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

			// Setup role and permission
			err := RegisterRole(cross, tc.setupRole)
			uassert.NoError(t, err)

			oldPermissionChecker := func(addr std.Address) error {
				if addr == tc.setupOwner {
					return nil
				}
				return prbac.ErrUnauthorized
			}
			err = RegisterPermission(cross, tc.setupRole, tc.setupPermission, oldPermissionChecker)
			uassert.NoError(t, err)

			// when
			newPermissionChecker := func(addr std.Address) error {
				return nil // Allow all
			}
			err = UpdatePermission(cross, tc.roleName, tc.permissionName, newPermissionChecker)

			// then
			if tc.expectedError != nil {
				uassert.ErrorIs(t, err, tc.expectedError)
			} else {
				// For success cases, check if error is nil
				if tc.name == "success - update existing permission" {
					uassert.NoError(t, err)
				} else {
					uassert.Error(t, err) // For other cases, expect an error
				}
			}
		})
	}
}

// Helper function to cleanup global state
func cleanup() {
	globalManager = prbac.New()
}
