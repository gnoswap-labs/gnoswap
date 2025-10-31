package rbac

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

var (
	testRoleName = "test_role"
	testAddr     = testutils.TestAddress("test")
	emptyAddr    = address("")
)

func TestRole_NewRole(t *testing.T) {
	tests := []struct {
		name     string
		roleName string
		addr     address
	}{
		{
			name:     "Create role with valid name and address",
			roleName: testRoleName,
			addr:     testAddr,
		},
		{
			name:     "Create role with empty address",
			roleName: testRoleName,
			addr:     emptyAddr,
		},
		{
			name:     "Create role with empty name",
			roleName: "",
			addr:     testAddr,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			role := NewRole(tt.roleName, tt.addr)

			uassert.NotNil(t, role)
			uassert.Equal(t, role.name, tt.roleName)
			uassert.Equal(t, role.address, tt.addr)
		})
	}
}

func TestRole_Name(t *testing.T) {
	tests := []struct {
		name         string
		roleName     string
		expectedName string
	}{
		{
			name:         "Get name from role",
			roleName:     testRoleName,
			expectedName: testRoleName,
		},
		{
			name:         "Get empty name from role",
			roleName:     "",
			expectedName: "",
		},
		{
			name:         "Get name with special characters",
			roleName:     "test@role#123",
			expectedName: "test@role#123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			role := NewRole(tt.roleName, testAddr)

			name := role.Name()
			uassert.Equal(t, name, tt.expectedName)
		})
	}
}

func TestRole_Address(t *testing.T) {
	tests := []struct {
		name            string
		addr            address
		expectedAddress address
	}{
		{
			name:            "Get address from role",
			addr:            testAddr,
			expectedAddress: testAddr,
		},
		{
			name:            "Get empty address from role",
			addr:            emptyAddr,
			expectedAddress: emptyAddr,
		},
		{
			name:            "Get another valid address",
			addr:            alice,
			expectedAddress: alice,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			role := NewRole(testRoleName, tt.addr)

			addr := role.Address()
			uassert.Equal(t, addr, tt.expectedAddress)
		})
	}
}

func TestRole_IsEmpty(t *testing.T) {
	tests := []struct {
		name     string
		addr     address
		expected bool
	}{
		{
			name:     "Role with valid address is not empty",
			addr:     testAddr,
			expected: false,
		},
		{
			name:     "Role with empty address is empty",
			addr:     emptyAddr,
			expected: true,
		},
		{
			name:     "Role with zero address is empty",
			addr:     zeroAddress,
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			role := NewRole(testRoleName, tt.addr)

			isEmpty := role.IsEmpty()
			uassert.Equal(t, isEmpty, tt.expected)
		})
	}
}

func TestRole_IsAuthorized(t *testing.T) {
	role := NewRole(testRoleName, testAddr)

	tests := []struct {
		name     string
		addr     address
		expected bool
	}{
		{
			name:     "Authorized address returns true",
			addr:     testAddr,
			expected: true,
		},
		{
			name:     "Unauthorized address returns false",
			addr:     alice,
			expected: false,
		},
		{
			name:     "Empty address returns false",
			addr:     emptyAddr,
			expected: false,
		},
		{
			name:     "Different address returns false",
			addr:     bob,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isAuthorized := role.IsAuthorized(tt.addr)
			uassert.Equal(t, isAuthorized, tt.expected)
		})
	}
}

func TestRole_setAddress(t *testing.T) {
	tests := []struct {
		name        string
		initialAddr address
		newAddr     address
	}{
		{
			name:        "Set new address successfully",
			initialAddr: testAddr,
			newAddr:     alice,
		},
		{
			name:        "Change from empty to valid address",
			initialAddr: emptyAddr,
			newAddr:     bob,
		},
		{
			name:        "Change from valid to empty address",
			initialAddr: testAddr,
			newAddr:     emptyAddr,
		},
		{
			name:        "Set same address again",
			initialAddr: testAddr,
			newAddr:     testAddr,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			role := NewRole(testRoleName, tt.initialAddr)

			// Verify initial address
			uassert.Equal(t, role.Address(), tt.initialAddr)

			// Set new address
			role.setAddress(tt.newAddr)

			// Verify address was updated
			uassert.Equal(t, role.Address(), tt.newAddr)

			// Verify authorization
			if tt.newAddr == emptyAddr {
				uassert.False(t, role.IsAuthorized(tt.initialAddr))
			} else {
				uassert.True(t, role.IsAuthorized(tt.newAddr))
				// Only check initial address if it's different from new address
				if tt.initialAddr != tt.newAddr {
					uassert.False(t, role.IsAuthorized(tt.initialAddr))
				}
			}
		})
	}
}

func TestRole_AddressUpdate(t *testing.T) {
	role := NewRole(testRoleName, alice)

	// Initially alice is authorized
	uassert.True(t, role.IsAuthorized(alice))
	uassert.False(t, role.IsAuthorized(bob))

	// Update to bob
	role.setAddress(bob)

	// Now bob is authorized, alice is not
	uassert.False(t, role.IsAuthorized(alice))
	uassert.True(t, role.IsAuthorized(bob))

	// Update back to alice
	role.setAddress(alice)

	// Alice is authorized again
	uassert.True(t, role.IsAuthorized(alice))
	uassert.False(t, role.IsAuthorized(bob))
}
