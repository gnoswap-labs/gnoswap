package rbac

import (
	"std"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestIsOwner(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	tests := []struct {
		name     string
		addr     std.Address
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
		addr     std.Address
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
	err := manager.TransferOwnership(DEV_OPS)
	if err != nil {
		t.Fatalf("Failed to transfer ownership: %v", err)
	}

	pendingOwner = GetPendingOwner()
	if pendingOwner != DEV_OPS {
		t.Errorf("GetPendingOwner() = %s, want %s", pendingOwner, DEV_OPS)
	}
}

func TestTransferOwnership(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Test successful transfer (we can't fully test the assertion since it depends on std.PreviousRealm())
	// We test the manager's functionality directly
	err := manager.TransferOwnership(DEV_OPS)
	if err != nil {
		t.Errorf("TransferOwnership failed: %v", err)
	}

	// Verify pending owner is set
	pendingOwner := GetPendingOwner()
	if pendingOwner != DEV_OPS {
		t.Errorf("Pending owner not set correctly, got %s, want %s", pendingOwner, DEV_OPS)
	}

	// Test transfer to empty address should fail
	err = manager.TransferOwnership("")
	if err == nil {
		t.Error("TransferOwnership with empty address should fail")
	}
}

func TestAcceptOwnership(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Set up pending owner
	err := manager.TransferOwnership(DEV_OPS)
	if err != nil {
		t.Fatalf("Failed to transfer ownership: %v", err)
	}

	// Test successful acceptance (we test the manager's functionality directly)
	err = manager.AcceptOwnership()
	if err != nil {
		t.Errorf("AcceptOwnership failed: %v", err)
	}

	// Verify ownership changed
	newOwner := GetOwner()
	if newOwner != DEV_OPS {
		t.Errorf("Owner not changed correctly, got %s, want %s", newOwner, DEV_OPS)
	}

	// Verify pending owner is cleared
	pendingOwner := GetPendingOwner()
	if pendingOwner != "" {
		t.Errorf("Pending owner should be cleared, got %s", pendingOwner)
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
	err := manager.TransferOwnership(DEV_OPS)
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
	err = manager.AcceptOwnership()
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