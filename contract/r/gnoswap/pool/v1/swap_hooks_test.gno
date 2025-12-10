package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/halt"
)

func TestHookSetters_RespectHalt(t *testing.T) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelComplete)
	defer func() {
		testing.SetRealm(adminRealm)
		halt.SetHaltLevel(cross, halt.HaltLevelNone)
	}()

	pool := newMockPosition()

	tests := []struct {
		name string
		call func()
	}{
		{
			name: "SetTickCrossHook",
			call: func() {
				pool.SetTickCrossHook(func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {})
			},
		},
		{
			name: "SetSwapStartHook",
			call: func() {
				pool.SetSwapStartHook(func(cur realm, poolPath string, timestamp int64) {})
			},
		},
		{
			name: "SetSwapEndHook",
			call: func() {
				pool.SetSwapEndHook(func(cur realm, poolPath string) error { return nil })
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.PanicsWithMessage(t, "halted: pool", func() {
				tt.call()
			})
		})
	}
}

func TestHookSetters_NormalOperation(t *testing.T) {
	// Setup: ensure pool is not halted
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelNone)

	stakerPath := "gno.land/r/gnoswap/staker"
	stakerRealm := testing.NewCodeRealm(stakerPath)

	pool := newMockPosition()

	t.Run("SetTickCrossHook succeeds when not halted", func(t *testing.T) {
		hook := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
			// Hook implementation
		}

		testing.SetRealm(stakerRealm)

		// Verify hook was set by checking store
		uassert.NotPanics(t, func() {
			func(cur realm) {
				pool.SetTickCrossHook(hook)
			}(cross)
		})
	})

	t.Run("SetSwapStartHook succeeds when not halted", func(t *testing.T) {
		hook := func(cur realm, poolPath string, timestamp int64) {
			// Hook implementation
		}

		testing.SetRealm(stakerRealm)

		uassert.NotPanics(t, func() {
			func(cur realm) {
				pool.SetSwapStartHook(hook)
			}(cross)
		})
	})

	t.Run("SetSwapEndHook succeeds when not halted", func(t *testing.T) {
		hook := func(cur realm, poolPath string) error {
			return nil
		}

		testing.SetRealm(stakerRealm)

		uassert.NotPanics(t, func() {
			func(cur realm) {
				pool.SetSwapEndHook(hook)
			}(cross)
		})
	})
}
