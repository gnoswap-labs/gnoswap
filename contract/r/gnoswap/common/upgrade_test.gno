package common

import (
	"chain/runtime"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRegisterInitializer(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		initializer          func(_ int, rlm realm) ICommon
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/common/v2"),
			initializer:     makeMockInitializer("v2"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer already registered",
		},
		{
			name:                 "register initializer is failed by invalid domain path",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: caller is not in the domain path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)

			if tt.setup != nil {
				tt.setup(cur, t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
					RegisterInitializer(cross(cur), tt.initializer)
				})
				return
			}

			RegisterInitializer(cross(cur), tt.initializer)

			impl := implementation.(*MockCommon)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		})
	}
}

func TestUpgradeImpl(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		packagePath          string
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "upgrade impl is success",
			packagePath:     "gno.land/r/gnoswap/common/v2",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "v2",
		},
		{
			name:                 "upgrade impl is failed by non-admin caller",
			packagePath:          "gno.land/r/gnoswap/common/v2",
			callerRealm:          testing.NewUserRealm("g1test"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1test is not admin",
		},
		{
			name:                 "upgrade impl is failed by non-registered version",
			packagePath:          "gno.land/r/gnoswap/common/v3",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/common/v3",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(cur, t)

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v2"))
			RegisterInitializer(cross(cur), makeMockInitializer("v2"))

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
					UpgradeImpl(cross(cur), tt.packagePath)
				})
			} else {
				UpgradeImpl(cross(cur), tt.packagePath)
			}

			impl := implementation.(*MockCommon)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
			uassert.Equal(t, "gno.land/r/gnoswap/common/"+tt.expectedVersion, GetImplementationPackagePath())
		})
	}
}

func TestHelpersRouteThroughImplementation(cur realm, t *testing.T) {
	const mockKey = "gno.land/r/gnoswap/mock/token.MOCK"

	resetTestState(cur, t)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
	RegisterInitializer(cross(cur), makeMockInitializer("v1", mockKey))

	uassert.NoError(t, IsRegistered(mockKey))
	uassert.Error(t, IsRegistered("gno.land/r/demo/defi/foo20.FOO"))
	uassert.Equal(t, int64(1000), TotalSupply(mockKey))
	uassert.Equal(t, int64(1000), BalanceOf(mockKey, adminAddr))
	uassert.NoError(t, Transfer(0, cur, mockKey, adminAddr, 1))

	uassert.PanicsContains(t, cur, "implementation is not initialized", func() {
		resetTestState(cur, t)
		BalanceOf(mockKey, adminAddr)
	})
}

func TestValidateTokenKey(cur realm, t *testing.T) {
	registerGrc20regImpl(cur, t)

	uassert.NoError(t, validateTokenKey("gno.land/r/demo/defi/foo20.FOO"))
	uassert.Error(t, validateTokenKey(""))
	uassert.Error(t, validateTokenKey("gno.land/r/demo/defi/foo20.FOO:500"))
	uassert.Error(t, IsRegistered("gno.land/r/demo/defi/foo20.FOO:500"))
	uassert.Error(t, ValidateRegistered("gno.land/r/demo/defi/foo20.FOO", "a:b"))
}
