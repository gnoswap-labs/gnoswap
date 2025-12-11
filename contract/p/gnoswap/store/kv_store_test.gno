package store

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestPermissionUpdateVsRemove(t *testing.T) {
	// Test that ensures proper permission management without None level
	// This addresses the issue where version manager needs clear distinction
	// between updating permissions and removing access entirely
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)
	caller1 := testutils.TestAddress("caller1")
	caller2 := testutils.TestAddress("caller2")

	// Add callers with different permissions
	err := store.AddAuthorizedCaller(caller1, Write)
	uassert.NoError(t, err)
	err = store.AddAuthorizedCaller(caller2, ReadOnly)
	uassert.NoError(t, err)

	// Test downgrading Write to ReadOnly (version manager hot-swap scenario)
	err = store.UpdateAuthorizedCaller(caller1, ReadOnly)
	uassert.NoError(t, err)

	authorized, _ := store.GetAuthorizedCallers()
	if authorized[caller1] != ReadOnly {
		t.Errorf("authorized[caller1] = %v, want %v", authorized[caller1], ReadOnly)
	}

	// Test that zero value Permission cannot be used
	var zeroPermission Permission
	err = store.UpdateAuthorizedCaller(caller2, zeroPermission)
	uassert.ErrorIs(t, ErrInvalidPermission, err)

	// Test removing caller completely (different from setting to ReadOnly)
	err = store.RemoveAuthorizedCaller(caller2)
	uassert.NoError(t, err)

	// Verify caller2 is completely removed, not just set to a lower permission
	authorized, _ = store.GetAuthorizedCallers()
	_, exists := authorized[caller2]
	uassert.False(t, exists, "Removed caller should not exist in authorized map")

	// Verify caller1 still has ReadOnly permission
	if authorized[caller1] != ReadOnly {
		t.Errorf("authorized[caller1] = %v, want %v", authorized[caller1], ReadOnly)
	}
}
