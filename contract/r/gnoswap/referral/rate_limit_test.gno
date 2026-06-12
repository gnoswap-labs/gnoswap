package referral

import (
	"chain/runtime/unsafe"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func TestRateLimit_AllowsFirstOperation(cur realm, t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()

	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")

	_, err := k.register(userAddr, referrerAddr)

	uassert.NoError(t, err)
	uassert.True(t, k.has(userAddr))
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_BlocksSecondOperationWithin24Hours(cur realm, t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")
	newReferrerAddr := testutils.TestAddress("referrer2")

	_, _ = k.register(userAddr, referrerAddr)

	// Second register attempt should be blocked by rate limit
	_, err := k.register(userAddr, newReferrerAddr)

	uassert.ErrorContains(t, err, ErrTooManyRequests)
	// verify original referral is preserved
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_IsAddressSpecific(cur realm, t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()

	k := setupRateLimitKeeper(t)

	user1 := testutils.TestAddress("user1")
	user2 := testutils.TestAddress("user2")
	referrer := testutils.TestAddress("referrer")

	_, err1 := k.register(user1, referrer)
	_, err2 := k.register(user2, referrer)

	uassert.NoError(t, err1)
	uassert.NoError(t, err2)
	uassert.True(t, k.has(user1))
	uassert.True(t, k.has(user2))
}

func TestRateLimit_ContractAddressNotRateLimited(cur realm, t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	userAddr := testutils.TestAddress("user1")

	// contract address registration (removal) is not rate limited
	for i := 0; i < 3; i++ {
		_, err := k.register(userAddr, contractAddress())
		uassert.NoError(t, err)
	}

	uassert.False(t, k.has(userAddr))
}

func TestRateLimit_TimeBoundaries(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		prefix          string
		timeSinceLastOp int64
		wantErr         string
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
			wantErr:         "",
		},
		{
			name:            "24h plus 1 second - allowed",
			prefix:          "after",
			timeSinceLastOp: MinTimeBetweenUpdates + 1,
			wantErr:         "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			cleanup := setupValidCaller(t)
			defer cleanup()
			k := setupRateLimitKeeper(t)

			user := testutils.TestAddress(tc.prefix + "_user")
			ref1 := testutils.TestAddress(tc.prefix + "_ref1")
			ref2 := testutils.TestAddress(tc.prefix + "_ref2")

			_, _ = k.register(user, ref1)

			// simulate time passage
			now := time.Now().Unix()
			k.lastOps.Set(user.String(), now-tc.timeSinceLastOp)

			// Try to register again (simulating update)
			_, err := k.register(user, ref2)

			if tc.wantErr != "" {
				uassert.ErrorContains(t, err, tc.wantErr)
			} else {
				uassert.NoError(t, err)
				ref, _ := k.get(user)
				uassert.Equal(t, ref2.String(), ref.String())
			}
		})
	}
}

func TestRateLimit_CheckRateLimitInternal(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setupLastOps func(k *keeper, addr string)
		wantErr      string
	}{
		{
			name:         "no entry exists - allowed",
			setupLastOps: func(k *keeper, addr string) {},
			wantErr:      "",
		},
		{
			name: "old entry (time=0) - allowed",
			setupLastOps: func(k *keeper, addr string) {
				k.lastOps.Set(addr, int64(0))
			},
			wantErr: "",
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			k := setupRateLimitKeeper(t)
			userAddr := testutils.TestAddress("user")
			tc.setupLastOps(k, userAddr.String())

			err := k.checkRateLimit(userAddr.String())

			if tc.wantErr == "" {
				uassert.NoError(t, err)
			} else {
				uassert.Equal(t, tc.wantErr, err.Error())
			}
		})
	}
}

func TestRateLimit_UnauthorizedCallerTakesPrecedence(cur realm, t *testing.T) {
	cleanup := setupRateLimitCaller(t, "unauthorized")
	defer cleanup()

	user := testutils.TestAddress("user")
	referrer := testutils.TestAddress("referrer")

	uassert.AbortsContains(t, cur, "unauthorized caller", func() {
		TryRegister(cross(cur), user, referrer.String())
	})
}

func TestRateLimit_SelfReferralTakesPrecedence(cur realm, t *testing.T) {
	cleanup := setupValidCaller(t)
	defer cleanup()
	k := setupRateLimitKeeper(t)

	user := testutils.TestAddress("user")

	_, err := k.register(user, user)

	uassert.ErrorContains(t, err, ErrSelfReferral)
}

func setupRateLimitKeeper(t *testing.T) *keeper {
	t.Helper()
	return NewKeeper().(*keeper)
}

func setupValidCaller(t *testing.T) func() {
	t.Helper()
	origCaller := unsafe.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupRateLimitCaller(t *testing.T, caller string) func() {
	t.Helper()
	origCaller := unsafe.OriginCaller()
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
