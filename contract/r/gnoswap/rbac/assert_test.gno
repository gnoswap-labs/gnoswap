package rbac

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestAssertIsOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Current owner should not panic",
			addr:        ADMIN,
			shouldPanic: false,
		},
		{
			name:        "Non-owner should panic",
			addr:        DEV_OPS,
			shouldPanic: true,
			expectedMsg: "caller is not owner",
		},
		{
			name:        "Empty address should panic",
			addr:        "",
			shouldPanic: true,
			expectedMsg: "caller is not owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Error("Expected panic but none occurred")
					}
					if tt.expectedMsg != "" {
						panicStr := ufmt.Sprintf("%v", r)
						if !contains(panicStr, tt.expectedMsg) {
							t.Errorf("Expected panic message to contain '%s', got '%s'", tt.expectedMsg, panicStr)
						}
					}
				}()
			}

			assertIsOwner(tt.addr)

			if tt.shouldPanic {
				t.Error("Expected panic but function completed normally")
			}
		})
	}
}

func TestAssertIsPendingOwner(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Pending owner should not panic",
			addr:        DEV_OPS,
			shouldPanic: false,
		},
		{
			name:        "Current owner should panic",
			addr:        ADMIN,
			shouldPanic: true,
			expectedMsg: "caller is not pending owner || caller: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
		},
		{
			name:        "Random address should panic",
			addr:        COMMUNITY_POOL_ADDR,
			shouldPanic: true,
			expectedMsg: "caller is not pending owner || caller: g100fnnlz5eh87p5hvwt8pf279lxaelm8k8md049",
		},
		{
			name:        "Empty address should panic",
			addr:        "",
			shouldPanic: true,
			expectedMsg: "caller is not pending owner || caller: ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(std.NewUserRealm(ADMIN))
		
			// Reset manager for test
			manager = prbac.NewRBACWithAddress(ADMIN)
		
			// Set up pending owner
			err := manager.TransferOwnership(DEV_OPS)
			if err != nil {
				t.Fatalf("Failed to set up pending owner: %v", err)
			}
			
			testing.SetRealm(std.NewUserRealm(tt.addr))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsPendingOwner(tt.addr)
				})
			} else {
				assertIsPendingOwner(tt.addr)
			}
		})
	}
}

func TestAssertIsAdmin(t *testing.T) {
	testing.SetRealm(std.NewUserRealm(ADMIN))
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
	initRbac()

	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Admin address should not panic",
			addr:        ADMIN,
			shouldPanic: false,
		},
		{
			name:        "Non-admin address should panic",
			addr:        DEV_OPS,
			shouldPanic: true,
			expectedMsg: "caller is not admin || caller: g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9",
		},
		{
			name:        "Empty address should panic",
			addr:        "",
			shouldPanic: true,
			expectedMsg: "caller is not admin || caller: ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(std.NewUserRealm(tt.addr))

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsAdmin(tt.addr)
				})
			} else {
				assertIsAdmin(tt.addr)
			}
		})
	}
}

func TestAssertIsAdminWithRoleUpdate(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// Change admin role to a different address
	err := manager.UpdateRoleAddress(prbac.ROLE_ADMIN.String(), DEV_OPS)
	if err != nil {
		t.Fatalf("Failed to update admin role address: %v", err)
	}

	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "New admin address should not panic",
			addr:        DEV_OPS,
			shouldPanic: false,
		},
		{
			name:        "Old admin address should panic",
			addr:        ADMIN,
			shouldPanic: true,
			expectedMsg: "caller is not admin || caller: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(std.NewUserRealm(tt.addr))
			
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsAdmin(tt.addr)
				})
			} else {
				assertIsAdmin(tt.addr)
			}
		})
	}
}

func TestAssertFunctionsIntegration(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
	initRbac()

	// Test complete ownership transfer workflow with assertions
	t.Run("Ownership transfer workflow with assertions", func(t *testing.T) {
		// Initially, ADMIN should be owner
		assertIsOwner(ADMIN)

		// DEV_OPS should not be owner or pending owner
		uassert.PanicsWithMessage(t, "caller is not owner || caller: g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9", func() {
			assertIsOwner(DEV_OPS)
		})

		// Clear the panic and continue with next test
	})

	t.Run("Pending owner assertions after transfer", func(t *testing.T) {
		// Transfer ownership
		manager = prbac.NewRBACWithAddress(ADMIN)
		testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
		initRbac()

		testing.SetRealm(std.NewUserRealm(ADMIN))
		err := manager.TransferOwnership(DEV_OPS)
		if err != nil {
			t.Fatalf("Failed to transfer ownership: %v", err)
		}

		// Now DEV_OPS should be pending owner
		assertIsPendingOwner(DEV_OPS)

		// ADMIN should not be pending owner
		uassert.PanicsWithMessage(t, "caller is not pending owner || caller: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
			assertIsPendingOwner(ADMIN)
		})
	})

	t.Run("Admin assertions", func(t *testing.T) {
		// Reset for clean admin test
		manager = prbac.NewRBACWithAddress(ADMIN)
		testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))
		initRbac()

		// ADMIN should pass admin assertion
		assertIsAdmin(ADMIN)

		// Non-admin should fail
		uassert.PanicsWithMessage(t, "caller is not admin || caller: g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9", func() {
			assertIsAdmin(DEV_OPS)
		})
	})
}

// Note: contains function is defined in rbac_test.gno to avoid duplication
