// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/legacy"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

// A patched fee collector does not make an old reward implementation wrap-safe.
// This is a terminal failure case: revive/Aborts does not roll back fixture state.
// The successful upgrade scenario switches implementations before claiming.
func main(cur realm) {
	const tokenPath = "gno.land/r/onbloc/bar.BAR"
	const feeAmount int64 = 4_000_000_000_000_000_000
	const share int64 = 2_000_000_000_000_000_000

	admin := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	feeSource := access.MustGetAddress(prbac.ROLE_STAKER.String())
	feeAddress := access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govAddress := access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	devOps := access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	user := testutils.TestAddress("legacy-boundary-user")

	testing.SetRealm(testing.NewUserRealm(admin))
	govStaker.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/gov/staker/legacy")
	protocolFee.UpgradeImpl(cross(cur), "gno.land/r/gnoswap/protocol_fee/v1")
	protocolFee.SetDevOpsPct(cross(cur), 5_000)
	gns.Transfer(cross(cur), user, 1_000_000)
	bar.Mint(cross(cur), feeSource, feeAmount)

	testing.SetRealm(testing.NewUserRealm(user))
	gns.Approve(cross(cur), govAddress, 1_000_000)
	govStaker.Delegate(cross(cur), user, 1_000_000, "")

	for i := 0; i < 4; i++ {
		testing.SetRealm(testing.NewUserRealm(feeSource))
		bar.Approve(cross(cur), feeAddress, feeAmount)
		protocolFee.AddToProtocolFee(cross(cur), tokenPath, feeAmount)
		testing.SetRealm(testing.NewUserRealm(user))
		govStaker.CollectProtocolFeeReward(cross(cur), tokenPath)
		if bar.BalanceOf(user) != share || bar.BalanceOf(devOps) != share {
			panic("legacy pre-boundary payout was incorrect")
		}
		bar.Transfer(cross(cur), feeSource, share)
		testing.SetRealm(testing.NewUserRealm(devOps))
		bar.Transfer(cross(cur), feeSource, share)
	}
	if govStaker.GetProtocolFeeAmount(tokenPath) != 8_000_000_000_000_000_000 {
		panic("legacy fees did not reach the intended boundary")
	}

	testing.SetRealm(testing.NewUserRealm(feeSource))
	bar.Approve(cross(cur), feeAddress, feeAmount)
	protocolFee.AddToProtocolFee(cross(cur), tokenPath, feeAmount)
	println("patched protocol_fee accepted the fifth fee; legacy gov/staker cannot fold it")
	testing.SetRealm(testing.NewUserRealm(user))
	govStaker.CollectProtocolFeeReward(cross(cur), tokenPath)
}

// Output:
// patched protocol_fee accepted the fifth fee; legacy gov/staker cannot fold it

// Error:
// int64 addition overflow
