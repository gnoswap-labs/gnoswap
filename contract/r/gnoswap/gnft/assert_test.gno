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
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
			},
			callerRealm: addr01Realm,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			// Token does not exist. The assertion should surface the
			// underlying GRC721 not-found error, not silently fail-open.
			name:        "non-existent token panics with not-found",
			setup:       func(t *testing.T) {},
			callerRealm: addr01Realm,
			tokenId:     999,
			shouldPanic: true,
			panicMsg:    errInvalidTokenId,
		},
		{
			// Edge case — token id 0. Same as any other non-existent id;
			// must fail-closed.
			name:        "token id zero panics with not-found",
			setup:       func(t *testing.T) {},
			callerRealm: addr01Realm,
			tokenId:     0,
			shouldPanic: true,
			panicMsg:    errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			if tt.setup != nil {
				tt.setup(t)
			}

			if tt.shouldPanic {
				testing.SetRealm(tt.callerRealm)
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsAllowedTransfer(tid(tt.tokenId))
				})
			} else {
				testing.SetRealm(tt.callerRealm)
				assertIsAllowedTransfer(tid(tt.tokenId))
			}
		})
	}
}
