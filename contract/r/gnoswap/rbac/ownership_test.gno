package rbac

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestIsOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	tests := []struct {
		name     string
		addr     address
		expected bool
	}{
		{
			name:     "Current owner should return true",
			addr:     ADMIN,
			expected: true,
		},
		{
			name:     "Non-owner should return false",
			addr:     DEV_OPS,
			expected: false,
		},
		{
			name:     "Empty address should return false",
			addr:     "",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsOwner(tt.addr)
			if result != tt.expected {
				t.Errorf("IsOwner(%s) = %v, want %v", tt.addr, result, tt.expected)
			}
		})
	}
}

func TestIsPendingOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Initially no pending owner
	if IsPendingOwner(DEV_OPS) {
		t.Error("Should not have pending owner initially")
	}

	// Note: Cannot test with actual pending owner due to ownable2step requiring std.PreviousRealm()
	// Test basic functionality with no pending owner
	tests := []struct {
		name     string
		addr     address
		expected bool
	}{
		{
			name:     "No pending owner - DEV_OPS should return false",
			addr:     DEV_OPS,
			expected: false,
		},
		{
			name:     "No pending owner - ADMIN should return false",
			addr:     ADMIN,
			expected: false,
		},
		{
			name:     "No pending owner - random address should return false",
			addr:     COMMUNITY_POOL_ADDR,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsPendingOwner(tt.addr)
			if result != tt.expected {
				t.Errorf("IsPendingOwner(%s) = %v, want %v", tt.addr, result, tt.expected)
			}
		})
	}
}

func TestGetOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	owner := GetOwner()
	if owner != ADMIN {
		t.Errorf("GetOwner() = %s, want %s", owner, ADMIN)
	}
}

func TestGetPendingOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Initially no pending owner
	pendingOwner := GetPendingOwner()
	if pendingOwner != "" {
		t.Errorf("GetPendingOwner() = %s, want empty string initially", pendingOwner)
	}

	// Set pending owner
	testing.SetRealm(testing.NewUserRealm(ADMIN))
	err := manager.TransferOwnershipBy(DEV_OPS, ADMIN)
	if err != nil {
		t.Fatalf("Failed to transfer ownership: %v", err)
	}

	pendingOwner = GetPendingOwner()
	if pendingOwner != DEV_OPS {
		t.Errorf("GetPendingOwner() = %s, want %s", pendingOwner, DEV_OPS)
	}
}

func TestTransferOwnership(t *testing.T) {
	tests := []struct {
		name                   string
		ownerAddr              address
		transferAddr           address
		transferRealm          runtime.Realm
		expectedHasAborted     bool
		expectedAbortedMessage string
	}{
		{
			name:                   "transfer ownership success",
			ownerAddr:              ADMIN,
			transferAddr:           testutils.TestAddress("user1"),
			transferRealm:          testing.NewUserRealm(ADMIN),
			expectedHasAborted:     false,
			expectedAbortedMessage: "",
		},
		{
			name:                   "transfer ownership failed to empty address",
			ownerAddr:              ADMIN,
			transferAddr:           "",
			transferRealm:          testing.NewUserRealm(ADMIN),
			expectedHasAborted:     true,
			expectedAbortedMessage: "invalid address",
		},
		{
			name:                   "transfer ownership failed to previous realm is not owner",
			ownerAddr:              ADMIN,
			transferAddr:           testutils.TestAddress("user1"),
			transferRealm:          testing.NewUserRealm(testutils.TestAddress("different_realm")),
			expectedHasAborted:     true,
			expectedAbortedMessage: "caller is not owner",
		},
		{
			name:                   "transfer ownership failed to caller is not owner",
			ownerAddr:              testutils.TestAddress("user1"),
			transferAddr:           testutils.TestAddress("user2"),
			transferRealm:          testing.NewUserRealm(testutils.TestAddress("user1")),
			expectedHasAborted:     true,
			expectedAbortedMessage: "caller is not owner",
		},
		{
			name:                   "transfer ownership failed to invalid address format",
			ownerAddr:              ADMIN,
			transferAddr:           address("invalid"),
			transferRealm:          testing.NewUserRealm(ADMIN),
			expectedHasAborted:     true,
			expectedAbortedMessage: "invalid address",
		},
		{
			name:                   "transfer ownership failed to malformed address",
			ownerAddr:              ADMIN,
			transferAddr:           address("g1"),
			transferRealm:          testing.NewUserRealm(ADMIN),
			expectedHasAborted:     true,
			expectedAbortedMessage: "invalid address",
		},
		{
			name:                   "transfer ownership to self should succeed",
			ownerAddr:              ADMIN,
			transferAddr:           ADMIN,
			transferRealm:          testing.NewUserRealm(ADMIN),
			expectedHasAborted:     false,
			expectedAbortedMessage: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// reset manager for test
			manager = prbac.NewRBACWithAddress(ADMIN)

			// setup current realm and origin caller
			func() {
				ctx := testing.GetContext()
				ctx.CurrentRealm = tt.transferRealm
				ctx.OriginCaller = tt.ownerAddr
				testing.SetContext(ctx)
			}()

			if tt.expectedHasAborted {
				uassert.AbortsContains(t, tt.expectedAbortedMessage, func() {
					TransferOwnership(cross, tt.transferAddr)
				})
			} else {
				TransferOwnership(cross, tt.transferAddr)
			}
		})
	}
}

func TestOwnership_TransferOwnershipTwice(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// First transfer
	testing.SetOriginCaller(ADMIN)
	TransferOwnership(cross, DEV_OPS)

	// Verify first pending owner
	if GetPendingOwner() != DEV_OPS {
		t.Errorf("First pending owner should be %s, got %s", DEV_OPS, GetPendingOwner())
	}

	// Second transfer to different address
	testing.SetOriginCaller(ADMIN)
	TransferOwnership(cross, COMMUNITY_POOL_ADDR)

	// Verify pending owner updated
	if GetPendingOwner() != COMMUNITY_POOL_ADDR {
		t.Errorf("Pending owner should be updated to %s, got %s", COMMUNITY_POOL_ADDR, GetPendingOwner())
	}

	// Owner should still be ADMIN
	if GetOwner() != ADMIN {
		t.Errorf("Owner should still be %s, got %s", ADMIN, GetOwner())
	}
}

func TestAcceptOwnership(t *testing.T) {
	tests := []struct {
		name                   string
		ownerAddr              address
		transferAddr           address
		acceptExecuteRealm     runtime.Realm
		acceptAddr             address
		expectedOwner          address
		expectedHasAborted     bool
		expectedAbortedMessage string
	}{
		{
			name:                   "accept ownership success",
			ownerAddr:              ADMIN,
			transferAddr:           DEV_OPS,
			acceptAddr:             DEV_OPS,
			acceptExecuteRealm:     testing.NewUserRealm(DEV_OPS),
			expectedOwner:          DEV_OPS,
			expectedHasAborted:     false,
			expectedAbortedMessage: "",
		},
		{
			name:                   "accept ownership failed to caller is not pending owner",
			ownerAddr:              ADMIN,
			transferAddr:           DEV_OPS,
			acceptAddr:             testutils.TestAddress("not-owner"),
			acceptExecuteRealm:     testing.NewUserRealm(testutils.TestAddress("not-owner")),
			expectedOwner:          ADMIN,
			expectedHasAborted:     true,
			expectedAbortedMessage: "caller is not pending owner",
		},
		{
			name:                   "accept ownership failed to previous realm is not owner",
			ownerAddr:              ADMIN,
			transferAddr:           DEV_OPS,
			acceptAddr:             DEV_OPS,
			acceptExecuteRealm:     testing.NewUserRealm(testutils.TestAddress("not-owner")),
			expectedOwner:          ADMIN,
			expectedHasAborted:     true,
			expectedAbortedMessage: "caller is not pending owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// reset manager for test
			manager = prbac.NewRBACWithAddress(tt.ownerAddr)

			// setup transfer ownership
			testing.SetOriginCaller(tt.ownerAddr)
			TransferOwnership(cross, tt.transferAddr)

			// setup current realm and origin caller
			func() {
				ctx := testing.GetContext()
				ctx.CurrentRealm = tt.acceptExecuteRealm
				ctx.OriginCaller = tt.acceptAddr
				testing.SetContext(ctx)
			}()

			if tt.expectedHasAborted {
				uassert.AbortsContains(t, tt.expectedAbortedMessage, func() {
					AcceptOwnership(cross)
				})
			} else {
				AcceptOwnership(cross)
			}

			if GetOwner() != tt.expectedOwner {
				t.Errorf("Owner not changed correctly, got %s, want %s", GetOwner(), tt.expectedOwner)
			}
		})
	}
}

func TestOwnership_AcceptOwnershipWithoutPendingOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Try to accept ownership without setting pending owner
	testing.SetOriginCaller(DEV_OPS)

	uassert.AbortsContains(t, "caller is not pending owner", func() {
		AcceptOwnership(cross)
	})

	// Owner should remain unchanged
	if GetOwner() != ADMIN {
		t.Errorf("Owner should still be %s, got %s", ADMIN, GetOwner())
	}

	// Pending owner should still be empty
	if GetPendingOwner() != "" {
		t.Errorf("Pending owner should be empty, got %s", GetPendingOwner())
	}
}

func TestOwnershipWorkflow(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Test complete ownership transfer workflow
	originalOwner := GetOwner()
	if originalOwner != ADMIN {
		t.Errorf("Original owner should be %s, got %s", ADMIN, originalOwner)
	}

	// Step 1: Transfer ownership
	testing.SetRealm(testing.NewUserRealm(ADMIN))
	err := manager.TransferOwnershipBy(DEV_OPS, ADMIN)
	if err != nil {
		t.Fatalf("Step 1 failed: %v", err)
	}

	// Verify state after transfer
	if GetOwner() != ADMIN {
		t.Error("Owner should not change until acceptance")
	}

	if GetPendingOwner() != DEV_OPS {
		t.Error("Pending owner should be set")
	}

	// Step 2: Accept ownership
	testing.SetRealm(testing.NewUserRealm(DEV_OPS))
	err = manager.AcceptOwnershipBy(DEV_OPS)
	if err != nil {
		t.Fatalf("Step 2 failed: %v", err)
	}

	// Verify final state
	if GetOwner() != DEV_OPS {
		t.Error("Owner should change after acceptance")
	}
	if GetPendingOwner() != "" {
		t.Error("Pending owner should be cleared after acceptance")
	}
}
