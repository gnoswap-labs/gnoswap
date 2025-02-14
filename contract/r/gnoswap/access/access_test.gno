package access

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
)

var (
	testAdmin  = testutils.TestAddress("admin")
	testUser   = testutils.TestAddress("user")
	testRouter = testutils.TestAddress("router")
	testPool   = testutils.TestAddress("pool")
)

func cleanup() {
	addressRegistry = avl.NewTree()
	pathRegistry = avl.NewTree()
	admin = testAdmin
}

func TestRegisterAddress(t *testing.T) {
	tests := []struct {
		name        string
		caller      std.Address
		role        string
		addr        std.Address
		path        string
		wantErr     bool
		errContains string
	}{
		{
			name:    "success - register router address",
			caller:  testAdmin,
			role:    ROLE_ROUTER,
			addr:    testRouter,
			path:    "router_path",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			Init(testAdmin)
			defer cleanup()

			err := RegisterAddress(tt.caller, tt.role, tt.addr, tt.path)
			if err != nil {
				t.Errorf("RegisterAddress() unexpected error: %v", err)
				return
			}

			// Verify address was registered correctly
			role, exists := addressRegistry.Get(tt.addr.String())
			if !exists {
				t.Errorf("RegisterAddress() address not found in registry")
				return
			}
			if role != tt.role {
				t.Errorf("RegisterAddress() got role = %v, want %v", role, tt.role)
			}

			// Verify path was registered correctly if provided
			if tt.path != "" {
				addr, exists := pathRegistry.Get(tt.path)
				if !exists {
					t.Errorf("RegisterAddress() path not found in registry")
					return
				}
				if addr != tt.addr.String() {
					t.Errorf("RegisterAddress() got path address = %v, want %v", addr, tt.addr.String())
				}
			}
		})
	}
}
