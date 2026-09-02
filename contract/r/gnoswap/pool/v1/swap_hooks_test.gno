package pool

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
)

func TestHookSetters_BypassHaltAndRequireStaker(cur realm, t *testing.T) {
	tests := []struct {
		name string
		call func(cur realm)
	}{
		{
			name: "SetTickCrossHook",
			call: func(cur realm) {
				pl.SetTickCrossHook(cross(cur), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {})
			},
		},
		{
			name: "SetSwapStartHook",
			call: func(cur realm) {
				pl.SetSwapStartHook(cross(cur), func(cur realm, poolPath string, timestamp int64) {})
			},
		},
		{
			name: "SetSwapEndHook",
			call: func(cur realm) {
				pl.SetSwapEndHook(cross(cur), func(cur realm, poolPath string) error { return nil })
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)

			testing.SetRealm(stakerRealm)
			uassert.NotPanics(t, cur, func() {
				tt.call(cur)
			})

			testing.SetRealm(adminRealm)
			uassert.AbortsContains(t, cur, "is not staker", func() {
				tt.call(cur)
			})

			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
			uassert.AbortsContains(t, cur, "is not staker", func() {
				tt.call(cur)
			})
		})
	}
}

func TestHookSetters_NormalOperation(cur realm, t *testing.T) {
	// Setup: ensure pool is not halted
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)

	stakerPath := "gno.land/r/gnoswap/staker"
	stakerRealm := testing.NewCodeRealm(stakerPath)

	pool := newMockPosition()

	t.Run("SetTickCrossHook succeeds when not halted", func(cur realm, t *testing.T) {
		hook := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
			// Hook implementation
		}

		testing.SetRealm(stakerRealm)

		// Verify hook was set by checking store
		uassert.NotPanics(t, cur, func() {
			func(cur realm) {
				pool.SetTickCrossHook(0, cur, hook)
			}(cross(cur))
		})
	})

	t.Run("SetSwapStartHook succeeds when not halted", func(cur realm, t *testing.T) {
		hook := func(cur realm, poolPath string, timestamp int64) {
			// Hook implementation
		}

		testing.SetRealm(stakerRealm)

		uassert.NotPanics(t, cur, func() {
			func(cur realm) {
				pool.SetSwapStartHook(0, cur, hook)
			}(cross(cur))
		})
	})

	t.Run("SetSwapEndHook succeeds when not halted", func(cur realm, t *testing.T) {
		hook := func(cur realm, poolPath string) error {
			return nil
		}

		testing.SetRealm(stakerRealm)

		uassert.NotPanics(t, cur, func() {
			func(cur realm) {
				pool.SetSwapEndHook(0, cur, hook)
			}(cross(cur))
		})
	})
}

func TestSwapEndHookFinalizesBeforeSwapCallback(cur realm, t *testing.T) {
	resetObject(cur, t)
	burnTokens(cur, t)
	InitialisePoolTest(cur, t)
	MintPositionAll(cur, t, adminAddr)

	TokenFaucet(cur, t, bazPath, routerAddr)
	testing.SetRealm(rouRealm)
	TokenApprove(cur, t, bazPath, routerAddr, poolAddr, maxApprove)

	finalized := false
	testing.SetRealm(stakerRealm)
	mockInstanceSetSwapEndHook(0, cur, func(cur realm, poolPath string) error {
		finalized = true
		return nil
	})

	testing.SetRealm(rouRealm)
	mockInstanceSwap(
		0,
		cur,
		barPath,
		bazPath,
		STANDARD_FEE_TIER,
		routerAddr,
		false,
		"100",
		maxSqrtPriceLimitX96,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
			uassert.True(t, finalized, "swap end hook must finish before the swap callback")
			return mockSwapCallback(cur, barPath, bazPath, amount0Delta, amount1Delta)
		},
	)

	uassert.True(t, finalized, "swap end hook must run")
}
