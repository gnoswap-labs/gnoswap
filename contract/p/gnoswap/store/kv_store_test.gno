package store

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestAuthorizedCallerPermissionValidation(t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)
	caller := testutils.TestAddress("caller")

	err := store.AddAuthorizedCaller(caller, None)
	uassert.ErrorIs(t, ErrInvalidPermission, err)

	err = store.AddAuthorizedCaller(caller, ReadOnly)
	uassert.NoError(t, err)

	err = store.UpdateAuthorizedCaller(caller, None)
	uassert.ErrorIs(t, ErrInvalidPermission, err)

	err = store.UpdateAuthorizedCaller(caller, Write)
	uassert.NoError(t, err)

	authorized, _ := store.GetAuthorizedCallers()
	if authorized[caller] != Write {
		t.Errorf("authorized[caller] = %v, want %v", authorized[caller], Write)
	}
}
