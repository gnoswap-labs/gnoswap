package gnft

import (
	"chain/runtime"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

// TestAssertIsAllowedTransfer covers the staking lock that gates transfers of
// tokens currently custodied by the staker.
//
// Policy: when the token's owner is the staker contract, only the staker
// itself may move the token. For any other owner, this assertion is a no-op
// and the underlying GRC721 ownership/approval checks apply.
func TestAssertIsAllowedTransfer(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		callerRealm runtime.Realm
		tokenId     uint64
		shouldPanic bool
		panicMsg    string
	}{
		{
			// Owner is a regular user. Lock does not apply, regardless of caller.
			name: "non-staked token allows arbitrary caller",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
			},
			callerRealm: addr02Realm,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			// Owner is a regular user. Lock does not apply even when the
			// owner themselves is the caller.
			name: "non-staked token allows owner caller",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
			},
			callerRealm: addr01Realm,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			// Token is custodied by the staker, and a non-staker calls.
			// Must panic with the staked-token-locked error.
			name: "staked token blocks user caller",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm: addr01Realm,
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-009] staked token is locked || token (1) is held by staker",
		},
		{
			// Token is custodied by the staker; even the position realm
			// (which is privileged elsewhere) cannot bypass the lock.
			name: "staked token blocks position realm caller",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm: positionRealm,
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-009] staked token is locked || token (1) is held by staker",
		},
		{
			// Token is custodied by the staker, and the staker itself calls.
			// Allowed — this is the unstake path.
			name: "staked token allows staker caller",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm: stakerRealm,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			// Token does not exist. The assertion should surface the
			// underlying GRC721 not-found error, not silently fail-open.
			name:        "non-existent token panics with not-found",
			setup:       func(t *testing.T) { resetObject(t) },
			callerRealm: addr01Realm,
			tokenId:     999,
			shouldPanic: true,
			panicMsg:    errInvalidTokenId,
		},
		{
			// Edge case — token id 0. Same as any other non-existent id;
			// must fail-closed.
			name:        "token id zero panics with not-found",
			setup:       func(t *testing.T) { resetObject(t) },
			callerRealm: addr01Realm,
			tokenId:     0,
			shouldPanic: true,
			panicMsg:    errInvalidTokenId,
		},
		{
			// After unstaking (token returned from staker to user) the
			// lock no longer applies — assertion must be a no-op.
			name: "post-unstake token is unlocked",
			setup: func(t *testing.T) {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, stakerRealm.Address(), tid(1))
				testing.SetRealm(stakerRealm)
				TransferFrom(cross, stakerRealm.Address(), addr01, tid(1))
			},
			callerRealm: addr02Realm,
			tokenId:     1,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup(t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					assertIsAllowedTransfer(tid(tt.tokenId))
				})
			} else {
				uassert.NotAborts(t, func() {
					assertIsAllowedTransfer(tid(tt.tokenId))
				})
			}
		})
	}
}
