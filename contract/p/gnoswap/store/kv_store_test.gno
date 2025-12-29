package store

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestNewKVStore_InitialState(t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	// Verify data is empty
	keys, err := store.GetAllKeys()
	uassert.NoError(t, err)
	uassert.Equal(t, 0, len(keys))

	// Verify domain address is correctly set
	uassert.Equal(t, domainAddr, store.GetDomainAddress())

	// Verify domain address has Write permission
	authorized, err := store.GetAuthorizedCallers()
	uassert.NoError(t, err)
	uassert.True(t, authorized[domainAddr] == Write, "domain address should have Write permission")
}

func TestGetDomainAddress(t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	uassert.Equal(t, domainAddr, store.GetDomainAddress())
}

func TestIsDomainAddress(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "same_address_returns_true",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr).(*kvStore)

				uassert.True(t, store.IsDomainAddress(domainAddr), "should return true for domain address")
			},
		},
		{
			name: "different_address_returns_false",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr).(*kvStore)

				uassert.False(t, store.IsDomainAddress(otherAddr), "should return false for different address")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestIsReadAuthorized(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "domain_address_authorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.True(t, store.IsReadAuthorized(domainAddr), "domain address should have read access")
			},
		},
		{
			name: "readonly_caller_authorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(caller, ReadOnly)

				uassert.True(t, store.IsReadAuthorized(caller), "ReadOnly caller should have read access")
			},
		},
		{
			name: "write_caller_authorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(caller, Write)

				uassert.True(t, store.IsReadAuthorized(caller), "Write caller should have read access")
			},
		},
		{
			name: "unregistered_caller_unauthorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				unregistered := testutils.TestAddress("unregistered")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.False(t, store.IsReadAuthorized(unregistered), "unregistered caller should not have read access")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestIsWriteAuthorized(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "domain_address_authorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.True(t, store.IsWriteAuthorized(domainAddr), "domain address should have write access")
			},
		},
		{
			name: "write_caller_authorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(caller, Write)

				uassert.True(t, store.IsWriteAuthorized(caller), "Write caller should have write access")
			},
		},
		{
			name: "readonly_caller_unauthorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(caller, ReadOnly)

				uassert.False(t, store.IsWriteAuthorized(caller), "ReadOnly caller should not have write access")
			},
		},
		{
			name: "unregistered_caller_unauthorized",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				unregistered := testutils.TestAddress("unregistered")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.False(t, store.IsWriteAuthorized(unregistered), "unregistered caller should not have write access")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

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

func TestAddAuthorizedCaller_Errors(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "already_registered",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(caller, Write)

				err := store.AddAuthorizedCaller(caller, ReadOnly)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerAlreadyRegistered)
			},
		},
		{
			name: "invalid_permission",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				var invalidPermission Permission = 99
				err := store.AddAuthorizedCaller(caller, invalidPermission)
				uassert.ErrorIs(t, err, ErrInvalidPermission)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")
				testing.SetRealm(testing.NewUserRealm(otherAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.AddAuthorizedCaller(caller, Write)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestUpdateAuthorizedCaller_Errors(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "not_found",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.UpdateAuthorizedCaller(caller, ReadOnly)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerNotFound)
			},
		},
		{
			name: "invalid_permission",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(caller, Write)

				var invalidPermission Permission = 100
				err := store.UpdateAuthorizedCaller(caller, invalidPermission)
				uassert.ErrorIs(t, err, ErrInvalidPermission)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")

				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(caller, Write)

				testing.SetRealm(testing.NewUserRealm(otherAddr))
				err := store.UpdateAuthorizedCaller(caller, ReadOnly)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestRemoveAuthorizedCaller_Errors(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "not_found",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.RemoveAuthorizedCaller(caller)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerNotFound)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")

				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(caller, Write)

				testing.SetRealm(testing.NewUserRealm(otherAddr))
				err := store.RemoveAuthorizedCaller(caller)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestKeyNotFound(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T, KVStore)
	}{
		{
			name: "Get",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.Get("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "Delete",
			verifyFn: func(t *testing.T, store KVStore) {
				err := store.Delete("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetInt64",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetInt64("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetUint64",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetUint64("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetBool",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetBool("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetString",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetString("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetAddress",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetAddress("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetTree",
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetTree("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.verifyFn(t, store)
		})
	}
}

func TestTypedGetters_TypeMismatch(t *testing.T) {
	testCases := []struct {
		name     string
		setupFn  func(KVStore)
		verifyFn func(*testing.T, KVStore)
	}{
		{
			name: "int64_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", "string value")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetInt64("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "uint64_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", int64(123))
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetUint64("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "bool_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", 1)
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetBool("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "string_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", 123)
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetString("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "address_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", "not an address")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetAddress("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "tree_type_mismatch",
			setupFn: func(store KVStore) {
				store.Set("key", "not a tree")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetTree("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(store)
			tc.verifyFn(t, store)
		})
	}
}

func TestGetAllKeys(t *testing.T) {
	testCases := []struct {
		name          string
		setupFn       func(KVStore)
		expectedCount int
	}{
		{
			name:          "empty_store",
			setupFn:       func(store KVStore) {},
			expectedCount: 0,
		},
		{
			name: "multiple_keys",
			setupFn: func(store KVStore) {
				store.Set("key1", "value1")
				store.Set("key2", "value2")
				store.Set("key3", "value3")
			},
			expectedCount: 3,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(store)

			keys, err := store.GetAllKeys()
			uassert.NoError(t, err)
			uassert.Equal(t, tc.expectedCount, len(keys))
		})
	}
}

func TestHas(t *testing.T) {
	testCases := []struct {
		name           string
		setupFn        func(KVStore)
		key            string
		expectedExists bool
	}{
		{
			name: "existing_key",
			setupFn: func(store KVStore) {
				store.Set("key", "value")
			},
			key:            "key",
			expectedExists: true,
		},
		{
			name:           "nonexistent_key",
			setupFn:        func(store KVStore) {},
			key:            "nonexistent",
			expectedExists: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(store)

			exists := store.Has(tc.key)
			uassert.Equal(t, tc.expectedExists, exists)
		})
	}
}

func TestSetAndGet_EdgeCases(t *testing.T) {
	testCases := []struct {
		name     string
		key      string
		value    any
		verifyFn func(*testing.T, any)
	}{
		{
			name:  "nil_value",
			key:   "key",
			value: nil,
			verifyFn: func(t *testing.T, value any) {
				uassert.True(t, value == nil, "value should be nil")
			},
		},
		{
			name:  "empty_string_key",
			key:   "",
			value: "value",
			verifyFn: func(t *testing.T, value any) {
				uassert.Equal(t, "value", value)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			err := store.Set(tc.key, tc.value)
			uassert.NoError(t, err)

			value, err := store.Get(tc.key)
			uassert.NoError(t, err)
			tc.verifyFn(t, value)
		})
	}
}

func TestDomainAddress_HasFullAccess(t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	err := store.Set("key", "value")
	uassert.NoError(t, err)

	value, err := store.Get("key")
	uassert.NoError(t, err)
	uassert.Equal(t, "value", value)

	err = store.Delete("key")
	uassert.NoError(t, err)
}

func TestAllTypedGetters_Success(t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	err := store.Set("int64_key", int64(123))
	uassert.NoError(t, err)
	err = store.Set("uint64_key", uint64(456))
	uassert.NoError(t, err)
	err = store.Set("bool_key", true)
	uassert.NoError(t, err)
	err = store.Set("string_key", "test")
	uassert.NoError(t, err)
	err = store.Set("address_key", domainAddr)
	uassert.NoError(t, err)
	tree := avl.NewTree()
	err = store.Set("tree_key", tree)
	uassert.NoError(t, err)

	i64, err := store.GetInt64("int64_key")
	uassert.NoError(t, err)
	uassert.Equal(t, int64(123), i64)

	u64, err := store.GetUint64("uint64_key")
	uassert.NoError(t, err)
	uassert.Equal(t, uint64(456), u64)

	b, err := store.GetBool("bool_key")
	uassert.NoError(t, err)
	uassert.True(t, b, "bool should be true")

	s, err := store.GetString("string_key")
	uassert.NoError(t, err)
	uassert.Equal(t, "test", s)

	addr, err := store.GetAddress("address_key")
	uassert.NoError(t, err)
	uassert.Equal(t, domainAddr, addr)

	retrievedTree, err := store.GetTree("tree_key")
	uassert.NoError(t, err)
	uassert.NotEqual(t, nil, retrievedTree)
}
