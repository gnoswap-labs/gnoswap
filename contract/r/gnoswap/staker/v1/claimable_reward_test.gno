package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gns"
)

func TestClaimableRewardsLedger(cur realm, t *testing.T) {
	ledger := NewClaimableRewards()

	uassert.Equal(t, int64(0), ledger.get(addr01, gnsPath))

	ledger.add(addr01, gnsPath, 100)
	ledger.add(addr01, gnsPath, 50)
	ledger.add(addr01, barPath, 7)
	ledger.add(addr02, gnsPath, 3)

	// Non-positive credits are dropped so the ledger only holds payable rows.
	ledger.add(addr01, bazPath, 0)
	ledger.add(addr01, bazPath, -5)

	uassert.Equal(t, int64(150), ledger.get(addr01, gnsPath))
	uassert.Equal(t, int64(7), ledger.get(addr01, barPath))
	uassert.Equal(t, int64(3), ledger.get(addr02, gnsPath))
	uassert.Equal(t, int64(0), ledger.get(addr01, bazPath))

	// A receiver only ever sees its own rows.
	entries := ledger.entriesOf(addr01)
	uassert.Equal(t, 2, len(entries))

	amountByToken := make(map[string]int64)
	for _, entry := range entries {
		amountByToken[entry.tokenPath] = entry.amount
	}
	uassert.Equal(t, int64(150), amountByToken[gnsPath])
	uassert.Equal(t, int64(7), amountByToken[barPath])

	ledger.remove(addr01, gnsPath)
	uassert.Equal(t, int64(0), ledger.get(addr01, gnsPath))
	uassert.Equal(t, 1, len(ledger.entriesOf(addr01)))
	uassert.Equal(t, int64(3), ledger.get(addr02, gnsPath))
}

func TestPayoutClaimableRewardsPaysAndClearsLedger(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	claimable := int64(12_345)
	instance.creditClaimableReward(addr01, GNS_TOKEN_KEY, claimable)

	// The payout checks the ROLE_STAKER reserve, while the local mock instance transfers
	// as staker/v1 (see stakerV1Addr), so both need to hold the reward.
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), stakerAddr, claimable)
	gns.Transfer(cross(cur), stakerV1Addr, claimable)

	balanceBefore := gns.BalanceOf(addr01)

	testing.SetRealm(stakerRealm)
	paid := instance.payoutClaimableRewards(0, cur, addr01)

	uassert.Equal(t, claimable, paid[GNS_TOKEN_KEY])
	uassert.Equal(t, balanceBefore+claimable, gns.BalanceOf(addr01))
	uassert.Equal(t, int64(0), instance.GetClaimableReward(addr01, GNS_TOKEN_KEY))
}

// A token the reserve cannot cover is left claimable rather than aborting the payout, so a
// short reserve can never strand a receiver's other rewards - and, more importantly, can
// never propagate back into unstaking.
func TestPayoutClaimableRewardsSkipsUnaffordableToken(cur realm, t *testing.T) {
	initStakerTest(cur, t)
	instance := getMockInstance()

	unaffordable := int64(1_000_000_000_000_000_000)
	instance.creditClaimableReward(addr01, GNS_TOKEN_KEY, unaffordable)

	balanceBefore := gns.BalanceOf(addr01)

	testing.SetRealm(stakerRealm)
	paid := instance.payoutClaimableRewards(0, cur, addr01)

	uassert.Equal(t, 0, len(paid))
	uassert.Equal(t, balanceBefore, gns.BalanceOf(addr01))
	uassert.Equal(t, unaffordable, instance.GetClaimableReward(addr01, GNS_TOKEN_KEY))
}
