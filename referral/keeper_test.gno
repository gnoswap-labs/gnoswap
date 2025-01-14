package referral

import (
	"math/rand"
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/consts"
)

const STRESS_TEST_NUM = 10000 // arbitrary number

var (
	validAddr1  = testutils.TestAddress("valid1")
	validAddr2  = testutils.TestAddress("valid2")
	invalidAddr = testutils.TestAddress("invalid")
)

func setupKeeper() *keeper { return NewKeeper().(*keeper) }

func mockValidCaller() func() {
	origCaller := std.GetOrigCaller()
	std.TestSetOrigCaller(consts.ROUTER_ADDR)
	return func() {
		std.TestSetOrigCaller(origCaller)
	}
}

func TestRegister(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		refAddr     std.Address
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name:        "valid registration",
			addr:        validAddr1,
			refAddr:     validAddr2,
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:    "unauthorized caller",
			addr:    validAddr1,
			refAddr: validAddr2,
			setupCaller: func() func() {
				origCaller := std.GetOrigCaller()
				std.TestSetOrigCaller(std.Address("unauthorized"))
				return func() {
					std.TestSetOrigCaller(origCaller)
				}
			},
			wantErr: true,
			errCode: ErrUnauthorized,
		},
		{
			name:        "self referral",
			addr:        validAddr1,
			refAddr:     validAddr1,
			setupCaller: mockValidCaller,
			wantErr:     true,
			errCode:     ErrSelfReferral,
		},
		{
			name:        "zero address referral",
			addr:        validAddr1,
			refAddr:     zeroAddress,
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.register(tt.addr, tt.refAddr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("register() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("register() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("register() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("register() unexpected error = %v", err)
			}
		})
	}
}

func TestUpdate(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		refAddr     std.Address
		setupState  func(*keeper)
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name:    "valid update",
			addr:    validAddr1,
			refAddr: validAddr2,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), "old_ref_addr")
			},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:        "update non-existent referral",
			addr:        validAddr1,
			refAddr:     validAddr2,
			setupState:  func(k *keeper) {},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:    "update to self referral",
			addr:    validAddr1,
			refAddr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			setupCaller: mockValidCaller,
			wantErr:     true,
			errCode:     ErrSelfReferral,
		},
		{
			name:    "update to zero address",
			addr:    validAddr1,
			refAddr: zeroAddress,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.update(tt.addr, tt.refAddr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("update() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("update() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("update() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("update() unexpected error = %v", err)
			}
		})
	}
}

func TestGet(t *testing.T) {
	tests := []struct {
		name       string
		addr       std.Address
		setupState func(*keeper)
		wantAddr   std.Address
		wantErr    bool
		errCode    int
	}{
		{
			name: "get existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			wantAddr: validAddr2,
			wantErr:  false,
		},
		{
			name:       "get non-existent referral",
			addr:       validAddr1,
			setupState: func(k *keeper) {},
			wantAddr:   zeroAddress,
			wantErr:    true,
			errCode:    ErrNotFound,
		},
		{
			name:       "get with invalid address",
			addr:       invalidAddr,
			setupState: func(k *keeper) {},
			wantAddr:   zeroAddress,
			wantErr:    true,
			errCode:    ErrNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)

			gotAddr, err := k.get(tt.addr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("get() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("get() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("get() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else {
				if err != nil {
					t.Errorf("get() unexpected error")
					return
				}
				if gotAddr != tt.wantAddr {
					t.Errorf("get() gotAddr = %v, want %v", gotAddr, tt.wantAddr)
				}
			}
		})
	}
}

func TestHas(t *testing.T) {
	tests := []struct {
		name       string
		addr       std.Address
		setupState func(*keeper)
		want       bool
	}{
		{
			name: "has existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			want: true,
		},
		{
			name:       "does not have referral",
			addr:       validAddr1,
			setupState: func(k *keeper) {},
			want:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)

			if got := k.has(tt.addr); got != tt.want {
				t.Errorf("has() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestRemove(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		setupState  func(*keeper)
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name: "remove existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:        "remove non-existent referral",
			addr:        validAddr1,
			setupState:  func(k *keeper) {},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.remove(tt.addr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("remove() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("remove() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("remove() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("remove() unexpected error = %v", err)
			}

			if k.has(tt.addr) {
				t.Errorf("remove() referral still exists after removal")
			}
		})
	}
}

func TestZeroAddressFlow(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	err := k.register(validAddr1, validAddr2)
	if err != nil {
		t.Fatalf("Failed to register initial referral: %v", err)
	}

	err = k.update(validAddr1, zeroAddress)
	if err != nil {
		t.Fatalf("Failed to update to zero address: %v", err)
	}

	_, err = k.get(validAddr1)
	if err == nil {
		t.Error("Expected error when getting removed referral")
	}
	referralErr, ok := err.(*ReferralError)
	if !ok || referralErr.Code != ErrNotFound {
		t.Errorf("Expected ErrNotFound, got %v", err)
	}

	if k.has(validAddr1) {
		t.Error("Expected has() to return false after zero address registration")
	}
}

func TestUpdateNonExistentReferral(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	err := k.update(validAddr1, validAddr2)
	if err != nil {
		t.Errorf("update() for non-existent referral failed: %v", err)
	}

	refAddr, err := k.get(validAddr1)
	if err != nil {
		t.Errorf("get() after update failed: %v", err)
	}
	if refAddr != validAddr2 {
		t.Errorf("got refAddr = %v, want %v", refAddr, validAddr2)
	}
}

func TestDuplicateRegistration(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	err := k.register(validAddr1, validAddr2)
	if err != nil {
		t.Fatalf("First registration failed: %v", err)
	}

	// register again with same address
	err = k.register(validAddr1, validAddr2)
	if err != nil {
		t.Errorf("Duplicate registration should succeed, got error: %v", err)
	}

	// original referral should be preserved
	refAddr, err := k.get(validAddr1)
	if err != nil || refAddr != validAddr2 {
		t.Errorf("Original referral was not preserved")
	}
}

func TestRemoveAndUpdate(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	err := k.register(validAddr1, validAddr2)
	if err != nil {
		t.Fatalf("Initial registration failed: %v", err)
	}

	err = k.remove(validAddr1)
	if err != nil {
		t.Fatalf("Remove failed: %v", err)
	}

	if k.has(validAddr1) {
		t.Error("Referral still exists after removal")
	}

	newRefAddr := testutils.TestAddress("valid3")
	err = k.update(validAddr1, newRefAddr)
	if err != nil {
		t.Errorf("Update after remove failed: %v", err)
	}

	refAddr, err := k.get(validAddr1)
	if err != nil || refAddr != newRefAddr {
		t.Error("New referral was not properly registered after remove")
	}
}

// TODO: Chained references seem to need discussion.
func TestChainedReferrals(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	addr1 := testutils.TestAddress("addr1")
	addr2 := testutils.TestAddress("addr2")
	addr3 := testutils.TestAddress("addr3")

	// A -> B -> C
	err := k.register(addr1, addr2)
	if err != nil {
		t.Fatalf("Failed to register addr1->addr2: %v", err)
	}

	err = k.register(addr2, addr3)
	if err != nil {
		t.Fatalf("Failed to register addr2->addr3: %v", err)
	}

	// remove middle node (B)
	err = k.remove(addr2)
	if err != nil {
		t.Fatalf("Failed to remove addr2: %v", err)
	}

	// A -> C
	refAddr, err := k.get(addr1)
	if err != nil || refAddr != addr2 {
		t.Error("addr1's referral should still point to addr2")
	}
}

func TestReferralCycles(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	addr1 := testutils.TestAddress("cycle1")
	addr2 := testutils.TestAddress("cycle2")
	addr3 := testutils.TestAddress("cycle3")

	// A -> B -> C
	err := k.register(addr1, addr2)
	if err != nil {
		t.Fatalf("Failed to register addr1->addr2: %v", err)
	}

	err = k.register(addr2, addr3)
	if err != nil {
		t.Fatalf("Failed to register addr2->addr3: %v", err)
	}

	// reference cycle: C -> A
	err = k.register(addr3, addr1)
	if err != nil {
		t.Fatalf("Failed to register addr3->addr1: %v", err)
	}

	refAddr, _ := k.get(addr1)
	if refAddr != addr2 {
		t.Error("addr1's referral should be addr2")
	}

	refAddr, _ = k.get(addr2)
	if refAddr != addr3 {
		t.Error("addr2's referral should be addr3")
	}

	refAddr, _ = k.get(addr3)
	if refAddr != addr1 {
		t.Error("addr3's referral should be addr1")
	}
}

func TestStateConsistency(t *testing.T) {
	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	// verify state consistency after performing multiple operations in succession
	operations := []struct {
		op   string
		addr std.Address
		ref  std.Address
	}{
		{"register", validAddr1, validAddr2},
		{"update", validAddr1, testutils.TestAddress("new")},
		{"remove", validAddr1, zeroAddress},
		{"register", validAddr1, validAddr2},
		{"update", validAddr1, zeroAddress},
		{"register", validAddr1, testutils.TestAddress("final")},
	}

	expectedExists := false
	var expectedRef std.Address

	for i, op := range operations {
		switch op.op {
		case "register":
			err := k.register(op.addr, op.ref)
			if err != nil {
				t.Errorf("Operation %d: register failed: %v", i, err)
			}
			expectedExists = true
			expectedRef = op.ref
		case "update":
			err := k.update(op.addr, op.ref)
			if err != nil {
				t.Errorf("Operation %d: update failed: %v", i, err)
			}
			expectedExists = op.ref != zeroAddress
			expectedRef = op.ref
		case "remove":
			err := k.remove(op.addr)
			if err != nil {
				t.Errorf("Operation %d: remove failed: %v", i, err)
			}
			expectedExists = false
		}

		// check state consistency
		exists := k.has(op.addr)
		if exists != expectedExists {
			t.Errorf("Operation %d: has() = %v, want %v", i, exists, expectedExists)
		}

		if expectedExists {
			ref, err := k.get(op.addr)
			if err != nil {
				t.Errorf("Operation %d: get() failed: %v", i, err)
			}
			if ref != expectedRef {
				t.Errorf("Operation %d: get() = %v, want %v", i, ref, expectedRef)
			}
		}
	}
}

func TestStress(t *testing.T) {
	t.Skip("Skipping stress test")

	k := setupKeeper()
	cleanup := mockValidCaller()
	defer cleanup()

	addresses := make([]std.Address, STRESS_TEST_NUM)

	for i := 0; i < STRESS_TEST_NUM; i++ {
		addresses[i] = testutils.TestAddress(ufmt.Sprintf("addr%d", i))
	}

	for i := 0; i < STRESS_TEST_NUM; i++ {
		err := k.register(addresses[i], addresses[(i+1)%STRESS_TEST_NUM])
		if err != nil {
			t.Fatalf("Registration failed at index %d: %v", i, err)
		}

		err = k.update(addresses[i], addresses[(i+2)%STRESS_TEST_NUM])
		if err != nil {
			t.Fatalf("Update failed at index %d: %v", i, err)
		}

		// remove some addresses
		if i%3 == 0 {
			err = k.remove(addresses[i])
			if err != nil {
				t.Fatalf("Remove failed at index %d: %v", i, err)
			}
		}

		// check data consistency
		if i%1000 == 0 {
			for j := 0; j <= i; j++ {
				if j%3 == 0 {
					// check removed address
					if k.has(addresses[j]) {
						t.Errorf("Removed address still exists at index %d", j)
					}
				} else {
					// check registered address
					refAddr, err := k.get(addresses[j])
					if err != nil {
						t.Errorf("Failed to get referral at index %d: %v", j, err)
					}
					expectedAddr := addresses[(j+2)%STRESS_TEST_NUM]
					if refAddr != expectedAddr {
						t.Errorf("Incorrect referral at index %d", j)
					}
				}
			}
		}
	}
}
