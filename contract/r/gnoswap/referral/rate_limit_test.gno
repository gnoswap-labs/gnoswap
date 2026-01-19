package referral

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func TestRateLimit_AllowsFirstOperation(t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()

	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")

	err := k.register(userAddr, referrerAddr)

	uassert.NoError(t, err)
	uassert.True(t, k.has(userAddr))
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_BlocksSecondOperationWithin24Hours(t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")
	newReferrerAddr := testutils.TestAddress("referrer2")

	k.register(userAddr, referrerAddr)

	// Second register attempt should be blocked by rate limit
	err := k.register(userAddr, newReferrerAddr)

	uassert.ErrorIs(t, err, ErrTooManyRequests)
	// verify original referral is preserved
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_IsAddressSpecific(t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()

	k := setupRateLimitKeeper(t)

	user1 := testutils.TestAddress("user1")
	user2 := testutils.TestAddress("user2")
	referrer := testutils.TestAddress("referrer")

	err1 := k.register(user1, referrer)
	err2 := k.register(user2, referrer)

	uassert.NoError(t, err1)
	uassert.NoError(t, err2)
	uassert.True(t, k.has(user1))
	uassert.True(t, k.has(user2))
}

func TestRateLimit_ContractAddressNotRateLimited(t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")

	// contract address registration (removal) is not rate limited
	for i := 0; i < 3; i++ {
		err := k.register(userAddr, contractAddress())
		uassert.NoError(t, err)
	}

	uassert.False(t, k.has(userAddr))
}

func TestRateLimit_TimeBoundaries(t *testing.T) {
	tests := []struct {
		name            string
		prefix          string
		timeSinceLastOp int64
		wantErr         error
	}{
		{
			name:            "24h minus 1 second - blocked",
			prefix:          "before",
			timeSinceLastOp: MinTimeBetweenUpdates - 1,
			wantErr:         ErrTooManyRequests,
		},
		{
			name:            "exactly 24h - allowed",
			prefix:          "exact",
			timeSinceLastOp: MinTimeBetweenUpdates,
			wantErr:         nil,
		},
		{
			name:            "24h plus 1 second - allowed",
			prefix:          "after",
			timeSinceLastOp: MinTimeBetweenUpdates + 1,
			wantErr:         nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup := setupValidCaller(t)
			defer cleanup()
			k := setupRateLimitKeeper(t)

			user := testutils.TestAddress(tc.prefix + "_user")
			ref1 := testutils.TestAddress(tc.prefix + "_ref1")
			ref2 := testutils.TestAddress(tc.prefix + "_ref2")

			k.register(user, ref1)

			// simulate time passage
			now := time.Now().Unix()
			k.lastOps.Set(user.String(), now-tc.timeSinceLastOp)

			// Try to register again (simulating update)
			err := k.register(user, ref2)

			if tc.wantErr != nil {
				uassert.ErrorIs(t, err, tc.wantErr)
			} else {
				uassert.NoError(t, err)
				ref, _ := k.get(user)
				uassert.Equal(t, ref2.String(), ref.String())
			}
		})
	}
}

func TestRateLimit_CheckRateLimitInternal(t *testing.T) {
	tests := []struct {
		name         string
		setupLastOps func(k *keeper, addr string)
		wantErr      error
	}{
		{
			name:         "no entry exists - allowed",
			setupLastOps: func(k *keeper, addr string) {},
			wantErr:      nil,
		},
		{
			name: "old entry (time=0) - allowed",
			setupLastOps: func(k *keeper, addr string) {
				k.lastOps.Set(addr, int64(0))
			},
			wantErr: nil,
		},
		{
			name: "invalid type stored - error",
			setupLastOps: func(k *keeper, addr string) {
				k.lastOps.Set(addr, "invalid")
			},
			wantErr: ErrInvalidTime,
		},
		{
			name: "recent entry - blocked",
			setupLastOps: func(k *keeper, addr string) {
				k.lastOps.Set(addr, time.Now().Unix()-MinTimeBetweenUpdates+1)
			},
			wantErr: ErrTooManyRequests,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			k := setupRateLimitKeeper(t)
			userAddr := testutils.TestAddress("user")
			tc.setupLastOps(k, userAddr.String())

			err := k.checkRateLimit(userAddr.String())

			if tc.wantErr == nil {
				uassert.NoError(t, err)
			} else {
				uassert.Equal(t, tc.wantErr.Error(), err.Error())
			}
		})
	}
}

func TestRateLimit_UnauthorizedCallerTakesPrecedence(t *testing.T) {
	cleanup := setupRateLimitCaller(t, "unauthorized")
	defer cleanup()

	user := testutils.TestAddress("user")
	referrer := testutils.TestAddress("referrer")

	uassert.AbortsContains(t, "unauthorized caller", func() {
		TryRegister(cross, user, referrer.String())
	})
}

func TestRateLimit_SelfReferralTakesPrecedence(t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	user := testutils.TestAddress("user")

	err := k.register(user, user)

	uassert.ErrorIs(t, err, ErrSelfReferral)
}

func setupRateLimitKeeper(t *testing.T) *keeper {
	t.Helper()
	return NewKeeper().(*keeper)
}

func setupValidCaller(t *testing.T) func() {
	t.Helper()
	origCaller := runtime.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupRateLimitCaller(t *testing.T, caller string) func() {
	t.Helper()
	origCaller := runtime.OriginCaller()
	switch caller {
	case "router":
		routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
		testing.SetOriginCaller(routerAddr)
	case "unauthorized":
		testing.SetOriginCaller(address("unauthorized"))
	}
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}
