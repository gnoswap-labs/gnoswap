package store

import (
	"strings"
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestNewKVStore_InitialState(cur realm, t *testing.T) {
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

func TestGetDomainAddress(cur realm, t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	uassert.Equal(t, domainAddr, store.GetDomainAddress())
}

func TestIsDomainAddress(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestIsAuthorized(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "domain_address_authorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.True(t, store.IsWriteAuthorized(domainAddr), "domain address should have write access")
			},
		},
		{
			name: "write_caller_authorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(0, cur, caller, Write)

				uassert.True(t, store.IsWriteAuthorized(caller), "Write caller should have write access")
			},
		},
		{
			name: "unregistered_caller_unauthorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				unregistered := testutils.TestAddress("unregistered")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.False(t, store.IsWriteAuthorized(unregistered), "unregistered caller should not have write access")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestIsWriteAuthorized(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "domain_address_authorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.True(t, store.IsWriteAuthorized(domainAddr), "domain address should have write access")
			},
		},
		{
			name: "write_caller_authorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				caller := testutils.TestAddress("caller")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				store.AddAuthorizedCaller(0, cur, caller, Write)

				uassert.True(t, store.IsWriteAuthorized(caller), "Write caller should have write access")
			},
		},
		{
			name: "unregistered_caller_unauthorized",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				unregistered := testutils.TestAddress("unregistered")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)

				uassert.False(t, store.IsWriteAuthorized(unregistered), "unregistered caller should not have write access")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestPermissionUpdateVsRemove(cur realm, t *testing.T) {
	// Test that ensures proper permission management without None level
	// This addresses the issue where version manager needs clear distinction
	// between updating permissions and removing access entirely
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)
	caller1 := testutils.TestAddress("caller1")

	// Add callers with different permissions
	err := store.AddAuthorizedCaller(0, cur, caller1, Write)
	uassert.NoError(t, err)

	authorized, _ := store.GetAuthorizedCallers()
	if authorized[caller1] != Write {
		t.Errorf("authorized[caller1] = %v, want %v", authorized[caller1], Write)
	}

	// Test that zero value Permission cannot be used
	var zeroPermission Permission
	err = store.UpdateAuthorizedCaller(0, cur, caller1, zeroPermission)
	uassert.ErrorIs(t, ErrInvalidPermission, err)

	// Test removing caller completely
	err = store.RemoveAuthorizedCaller(0, cur, caller1)
	uassert.NoError(t, err)

	// Verify caller1 is completely removed, not just set to a lower permission
	authorized, _ = store.GetAuthorizedCallers()
	_, exists := authorized[caller1]
	uassert.False(t, exists, "Removed caller should not exist in authorized map")
}

func TestAddAuthorizedCaller_Errors(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "already_registered",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(0, cur, caller, Write)

				err := store.AddAuthorizedCaller(0, cur, caller, Write)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerAlreadyRegistered)
			},
		},
		{
			name: "invalid_permission",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				var invalidPermission Permission = 99
				err := store.AddAuthorizedCaller(0, cur, caller, invalidPermission)
				uassert.ErrorIs(t, err, ErrInvalidPermission)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")
				testing.SetRealm(testing.NewUserRealm(otherAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.AddAuthorizedCaller(0, cur, caller, Write)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestUpdateAuthorizedCaller_Errors(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "not_found",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.UpdateAuthorizedCaller(0, cur, caller, Write)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerNotFound)
			},
		},
		{
			name: "invalid_permission",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(0, cur, caller, Write)

				var invalidPermission Permission = 100
				err := store.UpdateAuthorizedCaller(0, cur, caller, invalidPermission)
				uassert.ErrorIs(t, err, ErrInvalidPermission)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")

				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(0, cur, caller, Write)

				testing.SetRealm(testing.NewUserRealm(otherAddr))
				err := store.UpdateAuthorizedCaller(0, cur, caller, Write)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestRemoveAuthorizedCaller_Errors(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T)
	}{
		{
			name: "not_found",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")

				err := store.RemoveAuthorizedCaller(0, cur, caller)
				uassert.ErrorIs(t, err, ErrAuthorizedCallerNotFound)
			},
		},
		{
			name: "unauthorized_domain",
			verifyFn: func(cur realm, t *testing.T) {
				domainAddr := testutils.TestAddress("domain")
				otherAddr := testutils.TestAddress("other")

				testing.SetRealm(testing.NewUserRealm(domainAddr))
				store := NewKVStore(domainAddr)
				caller := testutils.TestAddress("caller")
				store.AddAuthorizedCaller(0, cur, caller, Write)

				testing.SetRealm(testing.NewUserRealm(otherAddr))
				err := store.RemoveAuthorizedCaller(0, cur, caller)
				uassert.ErrorIs(t, err, ErrUpdatePermissionDenied)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			tc.verifyFn(cur, t)
		})
	}
}

func TestKeyNotFound(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(cur realm, t *testing.T, store KVStore)
	}{
		{
			name: "Get",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.Get("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "Delete",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				err := store.Delete(0, cur, "nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetInt64",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetInt64("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetUint64",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetUint64("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetBool",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetBool("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetString",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetString("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetAddress",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetAddress("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
		{
			name: "GetBPTree",
			verifyFn: func(cur realm, t *testing.T, store KVStore) {
				_, err := store.GetBPTree("nonexistent")
				uassert.ErrorIs(t, err, ErrKeyNotFound)
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.verifyFn(cur, t, store)
		})
	}
}

func TestTypedGetters_TypeMismatch(cur realm, t *testing.T) {
	testCases := []struct {
		name     string
		setupFn  func(cur realm, store KVStore)
		verifyFn func(t *testing.T, store KVStore)
	}{
		{
			name: "int64_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", "string value")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetInt64("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "uint64_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", int64(123))
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetUint64("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "bool_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", 1)
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetBool("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "string_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", 123)
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetString("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "address_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", "not an address")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetAddress("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "bptree_type_mismatch",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", "not a tree")
			},
			verifyFn: func(t *testing.T, store KVStore) {
				_, err := store.GetBPTree("key")
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(cur, store)
			tc.verifyFn(t, store)
		})
	}
}

func TestGetAllKeys(cur realm, t *testing.T) {
	testCases := []struct {
		name         string
		setupFn      func(cur realm, store KVStore)
		expectedKeys []string
	}{
		{
			name:         "empty_store",
			setupFn:      func(cur realm, store KVStore) {},
			expectedKeys: []string{},
		},
		{
			name: "multiple_keys",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key1", "value1")
				store.Set(0, cur, "key2", "value2")
				store.Set(0, cur, "key3", "value3")
			},
			expectedKeys: []string{"key1", "key2", "key3"},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(cur, store)

			keys, err := store.GetAllKeys()
			uassert.NoError(t, err)
			uassert.Equal(t, len(tc.expectedKeys), len(keys))

			// Verify key format: "domainAddress:key"
			for _, key := range keys {
				parts := strings.Split(key, ":")
				uassert.Equal(t, 2, len(parts), "key should have format 'domainAddress:key'")

				// Verify domain address is valid
				addr := address(parts[0])
				uassert.True(t, addr.IsValid(), "domain address should be valid")
				uassert.Equal(t, domainAddr, addr, "domain address should match")

				// Verify actual key is in expected keys
				actualKey := parts[1]
				found := false
				for _, expectedKey := range tc.expectedKeys {
					if actualKey == expectedKey {
						found = true
						break
					}
				}
				uassert.True(t, found, "actual key should be in expected keys: "+actualKey)
			}
		})
	}
}

func TestHas(cur realm, t *testing.T) {
	testCases := []struct {
		name           string
		setupFn        func(cur realm, store KVStore)
		key            string
		expectedExists bool
	}{
		{
			name: "existing_key",
			setupFn: func(cur realm, store KVStore) {
				store.Set(0, cur, "key", "value")
			},
			key:            "key",
			expectedExists: true,
		},
		{
			name:           "nonexistent_key",
			setupFn:        func(cur realm, store KVStore) {},
			key:            "nonexistent",
			expectedExists: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			tc.setupFn(cur, store)

			exists := store.Has(tc.key)
			uassert.Equal(t, tc.expectedExists, exists)
		})
	}
}

func TestSetAndGet_EdgeCases(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			domainAddr := testutils.TestAddress("domain")
			testing.SetRealm(testing.NewUserRealm(domainAddr))
			store := NewKVStore(domainAddr)

			err := store.Set(0, cur, tc.key, tc.value)
			uassert.NoError(t, err)

			value, err := store.Get(tc.key)
			uassert.NoError(t, err)
			tc.verifyFn(t, value)
		})
	}
}

func TestDomainAddress_HasFullAccess(cur realm, t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	err := store.Set(0, cur, "key", "value")
	uassert.NoError(t, err)

	value, err := store.Get("key")
	uassert.NoError(t, err)
	uassert.Equal(t, "value", value)

	err = store.Delete(0, cur, "key")
	uassert.NoError(t, err)
}

func TestAllTypedGetters_Success(cur realm, t *testing.T) {
	domainAddr := testutils.TestAddress("domain")
	testing.SetRealm(testing.NewUserRealm(domainAddr))

	store := NewKVStore(domainAddr)

	err := store.Set(0, cur, "int64_key", int64(123))
	uassert.NoError(t, err)
	err = store.Set(0, cur, "uint64_key", uint64(456))
	uassert.NoError(t, err)
	err = store.Set(0, cur, "bool_key", true)
	uassert.NoError(t, err)
	err = store.Set(0, cur, "string_key", "test")
	uassert.NoError(t, err)
	err = store.Set(0, cur, "address_key", domainAddr)
	uassert.NoError(t, err)
	err = store.Set(0, cur, "bptree_key", bptree.NewBPTreeN(16))
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

	retrievedTree, err := store.GetBPTree("bptree_key")
	uassert.NoError(t, err)
	uassert.NotEqual(t, nil, retrievedTree)
}
