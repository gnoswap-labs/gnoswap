package community_pool

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
)

func TestRenderUsesWithdrawalGate(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	withdrawHalted := halt.IsHaltedWithdraw()
	communityHalted := halt.IsHaltedCommunityPool()
	defer func() {
		halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, withdrawHalted)
		halt.SetOperationStatus(cross(cur), halt.OpTypeCommunityPool, communityHalted)
	}()

	// TransferToken checks the withdrawal gate, not the community-pool flag.
	halt.SetOperationStatus(cross(cur), halt.OpTypeCommunityPool, true)
	halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, false)
	uassert.True(t, strings.Contains(Render(""), "| Withdrawals halted | false |"))

	halt.SetOperationStatus(cross(cur), halt.OpTypeCommunityPool, false)
	halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, true)
	uassert.True(t, strings.Contains(Render(""), "| Withdrawals halted | true |"))
	uassert.Equal(t, "404\n", Render("balances"))
}
