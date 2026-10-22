// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

// Reuse the same funded tokens rather than seeding impossible accounting state.
// Each recipient accrues 40e18 units over 20 cycles, crossing the signed boundary
// twice and the full 2^64 boundary twice, while the supply always fits int64.
func main(cur realm) {
	const tokenPath = "gno.land/r/onbloc/bar.BAR"
	const feeAmount int64 = 4_000_000_000_000_000_000
	const share int64 = 2_000_000_000_000_000_000
	const wrappedTotal int64 = 3_106_511_852_580_896_768 // 40e18 modulo 2^64

	admin := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	feeSource := access.MustGetAddress(prbac.ROLE_STAKER.String())
	feeAddress := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govAddress := access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	devOps := access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	user := testutils.TestAddress("fee-rollover-user")

	testing.SetRealm(testing.NewUserRealm(admin))
	protocol_fee.SetDevOpsPct(cross(cur), 5000)
	gns.Transfer(cross(cur), user, 1_000_000)
	bar.Mint(cross(cur), feeSource, feeAmount)
	supply := bar.TotalSupply()

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Approve(cross(cur), govAddress, 1_000_000)
	staker.Delegate(cross(cur), user, 1_000_000, "")

	for i := 0; i < 20; i++ {
		testing.SetRealm(testing.NewUserRealm(feeSource))
		bar.Approve(cross(cur), feeAddress, feeAmount)
		protocol_fee.AddToProtocolFee(cross(cur), tokenPath, feeAmount)

		testing.SetRealm(testing.NewUserRealm(user))
		staker.CollectProtocolFeeReward(cross(cur), tokenPath)
		if bar.BalanceOf(user) != share || bar.BalanceOf(devOps) != share {
			panic("fee rollover lost or duplicated a recipient payout")
		}
		if bar.BalanceOf(feeAddress) != 0 || bar.BalanceOf(govAddress) != 0 {
			panic("fee rollover left an unsettled balance")
		}
		_, pending, err := staker.GetClaimableRewardByAddress(user)
		if err != nil || pending[tokenPath] != 0 {
			panic("already collected fee remains claimable")
		}

		// A second collect must not pay again, including after counter rollover.
		staker.CollectProtocolFeeReward(cross(cur), tokenPath)
		if bar.BalanceOf(user) != share {
			panic("fee rollover allowed a duplicate claim")
		}
		bar.Transfer(cross(cur), feeSource, share)
		testing.SetRealm(testing.NewUserRealm(devOps))
		bar.Transfer(cross(cur), feeSource, share)
	}

	if bar.TotalSupply() != supply || bar.BalanceOf(feeSource) != feeAmount {
		panic("recycled fees did not conserve token supply and source balance")
	}
	if protocol_fee.GetAccuTransferToGovStakerByTokenPath(tokenPath) != wrappedTotal ||
		protocol_fee.GetActualDistributedToGovStakerByTokenPath(tokenPath) != wrappedTotal ||
		protocol_fee.GetAccuTransferToDevOpsByTokenPath(tokenPath) != wrappedTotal ||
		protocol_fee.GetActualDistributedToDevOpsByTokenPath(tokenPath) != wrappedTotal ||
		staker.GetProtocolFeeAmount(tokenPath) != wrappedTotal {
		panic("lifetime fee totals disagree after rollover")
	}
	if len(protocol_fee.GetReservedTokens()) != 0 {
		panic("fully distributed fee remains reserved")
	}
	println("20 recycled fee cycles: both recipients paid exactly, no duplicate claims, supply conserved")
}

// Output:
// 20 recycled fee cycles: both recipients paid exactly, no duplicate claims, supply conserved
