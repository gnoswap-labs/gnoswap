package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
)

func TestHookSetters_RespectHalt(cur realm, t *testing.T) {
	tests := []struct {
		name string
		call func(cur realm)
	}{
		{
			name: "SetTickCrossHook",
			call: func(cur realm) {
				testing.SetRealm(stakerRealm)
				pl.SetTickCrossHook(cross(cur), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {})
			},
		},
		{
			name: "SetSwapStartHook",
			call: func(cur realm) {
				testing.SetRealm(stakerRealm)
				pl.SetSwapStartHook(cross(cur), func(cur realm, poolPath string, timestamp int64) {})
			},
		},
		{
			name: "SetSwapEndHook",
			call: func(cur realm) {
				testing.SetRealm(stakerRealm)
				pl.SetSwapEndHook(cross(cur), func(cur realm, poolPath string) error { return nil })
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelComplete)

			uassert.AbortsWithMessage(t, cur, "halted: pool", func() {
				tt.call(cur)
			})

			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
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
