package referral

import (
	"chain/runtime"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func TestRateLimit_AllowsFirstOperation(t *testing.T) {
	cleanup := setupValidCaller()
	defer cleanup()
	k := setupRateLimitKeeper()

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")

	err := k.register(userAddr, referrerAddr)

	uassert.NoError(t, err)
	uassert.True(t, k.has(userAddr))
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_BlocksSecondOperationWithin24Hours(t *testing.T) {
	cleanup := setupValidCaller()
	defer cleanup()
	k := setupRateLimitKeeper()

	userAddr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")
	newReferrerAddr := testutils.TestAddress("referrer2")

	k.register(userAddr, referrerAddr)

	err := k.update(userAddr, newReferrerAddr)

	uassert.ErrorIs(t, err, ErrTooManyRequests)
	// verify original referral is preserved
	ref, _ := k.get(userAddr)
	uassert.Equal(t, referrerAddr.String(), ref.String())
}

func TestRateLimit_IsAddressSpecific(t *testing.T) {
	cleanup := setupValidCaller()
	defer cleanup()
	k := setupRateLimitKeeper()

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

func TestRateLimit_OperationCombinations(t *testing.T) {
	tests := []struct {
		name     string
		prefix   string
		firstOp  func(k *keeper, user, ref1, ref2 address) error
		secondOp func(k *keeper, user, ref1, ref2 address) error
		wantErr  error
	}{
		{
			name:   "register then update",
			prefix: "reg_upd",
			firstOp: func(k *keeper, user, ref1, _ address) error {
				return k.register(user, ref1)
			},
			secondOp: func(k *keeper, user, _, ref2 address) error {
				return k.update(user, ref2)
			},
			wantErr: ErrTooManyRequests,
		},
		{
			name:   "update then register",
			prefix: "upd_reg",
			firstOp: func(k *keeper, user, ref1, _ address) error {
				return k.update(user, ref1)
			},
			secondOp: func(k *keeper, user, _, ref2 address) error {
				return k.register(user, ref2)
			},
			wantErr: ErrTooManyRequests,
		},
		{
			name:   "update then update",
			prefix: "upd_upd",
			firstOp: func(k *keeper, user, ref1, _ address) error {
				return k.update(user, ref1)
			},
			secondOp: func(k *keeper, user, _, ref2 address) error {
				return k.update(user, ref2)
			},
			wantErr: ErrTooManyRequests,
		},
		{
			name:   "register then remove",
			prefix: "reg_rem",
			firstOp: func(k *keeper, user, ref1, _ address) error {
				return k.register(user, ref1)
			},
			secondOp: func(k *keeper, user, _, _ address) error {
				return k.remove(user)
			},
			wantErr: ErrTooManyRequests,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			user := testutils.TestAddress(tc.prefix + "_user")
			ref1 := testutils.TestAddress(tc.prefix + "_ref1")
			ref2 := testutils.TestAddress(tc.prefix + "_ref2")

			err := tc.firstOp(k, user, ref1, ref2)
			uassert.NoError(t, err)

			err = tc.secondOp(k, user, ref1, ref2)
			uassert.ErrorIs(t, err, tc.wantErr)
		})
	}
}

func TestRateLimit_ZeroAddressNotRateLimited(t *testing.T) {
	cleanup := setupValidCaller()
	defer cleanup()
	k := setupRateLimitKeeper()

	userAddr := testutils.TestAddress("user1")

	// zero address registration is not rate limited
	for i := 0; i < 3; i++ {
		err := k.register(userAddr, zeroAddress)
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
			cleanup := setupValidCaller()
			defer cleanup()
			k := setupRateLimitKeeper()

			user := testutils.TestAddress(tc.prefix + "_user")
			ref1 := testutils.TestAddress(tc.prefix + "_ref1")
			ref2 := testutils.TestAddress(tc.prefix + "_ref2")

			k.register(user, ref1)

			// simulate time passage
			now := time.Now().Unix()
			k.lastOps.Set(user.String(), now-tc.timeSinceLastOp)

			err := k.update(user, ref2)

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
			k := setupRateLimitKeeper()
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
	cleanup := setupRateLimitCaller("unauthorized")
	defer cleanup()
	k := setupRateLimitKeeper()

	user := testutils.TestAddress("user")
	referrer := testutils.TestAddress("referrer")

	err := k.register(user, referrer)

	uassert.Error(t, err)
	uassert.True(t, strings.Contains(err.Error(), "unauthorized caller"))
}

func TestRateLimit_SelfReferralTakesPrecedence(t *testing.T) {
	cleanup := setupValidCaller()
	defer cleanup()
	k := setupRateLimitKeeper()

	user := testutils.TestAddress("user")

	err := k.register(user, user)

	uassert.ErrorIs(t, err, ErrSelfReferral)
}

func setupRateLimitKeeper() *keeper {
	return NewKeeper().(*keeper)
}

func setupValidCaller() func() {
	origCaller := runtime.OriginCaller()
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	testing.SetOriginCaller(routerAddr)
	return func() {
		testing.SetOriginCaller(origCaller)
	}
}

func setupRateLimitCaller(caller string) func() {
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
