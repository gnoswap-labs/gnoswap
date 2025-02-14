package access

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/rbac"
)

var (
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
	addr03 = testutils.TestAddress("addr03")
)

func resetTestState(t *testing.T) {
	t.Helper()
	currentConfig = nil
}

func createTestConfig() *Config {
	return &Config{
		AdminAddr:      addr01,
		GovernanceAddr: addr01,
		GovStakerAddr:  addr01,
		RouterAddr:     addr01,
		PoolAddr:       addr01,
		PositionAddr:   addr01,
		StakerAddr:     addr01,
		LaunchpadAddr:  addr01,
		EmissionAddr:   addr01,
	}
}

func TestInitialize(t *testing.T) {
	t.Skip()
	t.Run("success with valid config", func(t *testing.T) {
		cfg := createTestConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)
		resetTestState(t)
	})

	t.Run("error with nil config", func(t *testing.T) {
		err := Initialize(nil)
		uassert.Error(t, err)
		resetTestState(t)
	})
}

func TestRolePermissions(t *testing.T) {
	cfg := &Config{
		AdminAddr:      addr01,
		GovernanceAddr: addr02,
		GovStakerAddr:  addr03,
	}
	err := Initialize(cfg)
	uassert.NoError(t, err)

	tests := []struct {
		name        string
		checkFunc   func(std.Address) error
		validAddr   std.Address
		invalidAddr std.Address
	}{
		{
			name:        "AdminOnly",
			checkFunc:   AdminOnly,
			validAddr:   addr01,
			invalidAddr: addr02,
		},
		{
			name:        "GovernanceOnly",
			checkFunc:   GovernanceOnly,
			validAddr:   addr02,
			invalidAddr: addr01,
		},
		{
			name:        "GovStakerOnly",
			checkFunc:   GovStakerOnly,
			validAddr:   addr03,
			invalidAddr: addr01,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name+" with valid address", func(t *testing.T) {
			err := tt.checkFunc(tt.validAddr)
			uassert.NoError(t, err)
		})

		t.Run(tt.name+" with invalid address", func(t *testing.T) {
			err := tt.checkFunc(tt.invalidAddr)
			uassert.Error(t, err)
		})
	}
}

func TestUpdateRoleAddress(t *testing.T) {
	t.Skip()
	// Setup initial configuration
	cfg := createTestConfig()
	err := Initialize(cfg)
	uassert.NoError(t, err)

	t.Run("update admin role address", func(t *testing.T) {
		// Initially addr01 should have admin access
		err := AdminOnly(addr01)
		uassert.NoError(t, err)

		// Update admin address to addr02
		err = UpdateRoleAddress(ROLE_ADMIN, addr02)
		uassert.NoError(t, err)

		// Now addr01 should not have access
		err = AdminOnly(addr01)
		uassert.Error(t, err)

		// But addr02 should have access
		err = AdminOnly(addr02)
		uassert.NoError(t, err)
	})

	t.Run("update non-existent role", func(t *testing.T) {
		err := UpdateRoleAddress("non_existent_role", addr01)
		uassert.Error(t, err)
	})
}

func TestMultipleInitialize(t *testing.T) {
	t.Skip()
	// First initialization
	cfg1 := createTestConfig()
	err := Initialize(cfg1)
	uassert.NoError(t, err)

	// Second initialization with different addresses
	cfg2 := &Config{
		AdminAddr:      addr02,
		GovernanceAddr: addr02,
		GovStakerAddr:  addr02,
	}
	err = Initialize(cfg2)
	uassert.Error(t, err) // Should fail because roles are already registered
}

func TestUserRealm(t *testing.T) {
	t.Skip()
	cfg := createTestConfig()
	err := Initialize(cfg)
	uassert.NoError(t, err)

	t.Run("test user role permissions", func(t *testing.T) {
		// Test with different types of realms and addresses
		tests := []struct {
			name      string
			role      string
			addr      std.Address
			shouldErr bool
		}{
			{
				name:      "admin address accessing admin role",
				role:      ROLE_ADMIN,
				addr:      addr01,
				shouldErr: false,
			},
			{
				name:      "non-admin address accessing admin role",
				role:      ROLE_ADMIN,
				addr:      addr02,
				shouldErr: true,
			},
			{
				name:      "governance address accessing governance role",
				role:      ROLE_GOVERNANCE,
				addr:      addr01,
				shouldErr: false,
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				err := rbac.CheckPermission(tt.role, PERM_ACCESS, tt.addr)
				if tt.shouldErr {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			})
		}
	})
}
