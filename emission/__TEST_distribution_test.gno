package emission

import (
	"std"
	"testing"

	"gno.land/r/demo/gns"
)

func TestEmitGns(t *testing.T) {
	shouldEQ(t, gns.TotalSupply(), 100000000000000) // GSA has
	shouldEQ(t, gnsBalance(emissionAddr), 0)

	EmitGns() // 1 ~ 123 height

	shouldEQ(t, gnsBalance(emissionAddr), 4387842345)
	shouldEQ(t, gns.TotalSupply(), 100000000000000+4387842345)

	shouldEQ(t, std.GetHeight(), 123)
}

func TestDistributeToTarget(t *testing.T) {
	shouldEQ(t, gnsBalance(emissionAddr), 4387842345)
	DistributeToTarget(gnsBalance(emissionAddr))
	shouldEQ(t, gnsBalance(emissionAddr), 1) // 1 left
}

func TestDistributeToTargetAfter5Block(t *testing.T) {
	std.TestSkipHeights(5)
	EmitGns()
	shouldEQ(t, gnsBalance(emissionAddr), 178367576)

	DistributeToTarget(gnsBalance(emissionAddr))
	shouldEQ(t, gnsBalance(emissionAddr), 1) // 1 left again
}

func TestChangeDistributionPctByAdmin(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	shouldEQ(t, GetDistributionPct(LIQUIDITY_STAKING), 7500)
	shouldEQ(t, GetDistributionPct(DEVOPS), 2000)

	ChangeDistributionPct02(
		1, 5000,
		2, 4500,
	)
	shouldEQ(t, GetDistributionPct(LIQUIDITY_STAKING), 5000)
	shouldEQ(t, GetDistributionPct(DEVOPS), 4500)

	ChangeDistributionPct03(
		1, 5000,
		2, 4000,
		3, 1000,
	)
	shouldEQ(t, GetDistributionPct(LIQUIDITY_STAKING), 5000)
	shouldEQ(t, GetDistributionPct(DEVOPS), 4000)
	shouldEQ(t, GetDistributionPct(COMMUNITY_POOL), 1000)

	ChangeDistributionPct04(
		1, 10000,
		2, 0,
		3, 0,
		4, 0,
	)
	shouldEQ(t, GetDistributionPct(LIQUIDITY_STAKING), 10000)
	shouldEQ(t, GetDistributionPct(DEVOPS), 0)
	shouldEQ(t, GetDistributionPct(COMMUNITY_POOL), 0)
	shouldEQ(t, GetDistributionPct(XGNS), 0)
}
