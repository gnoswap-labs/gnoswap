// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/gns"
	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/legacy"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/legacy"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

var t = &testing.T{}

const (
	govStakerLegacyPath   = "gno.land/r/gnoswap/gov/staker/legacy"
	govStakerV1Path       = "gno.land/r/gnoswap/gov/staker/v1"
	protocolFeeLegacyPath = "gno.land/r/gnoswap/protocol_fee/legacy"
	protocolFeeV1Path     = "gno.land/r/gnoswap/protocol_fee/v1"
	barTokenPath          = "gno.land/r/onbloc/bar.BAR"

	ordinaryFeeAmount  int64 = 2_000_000
	ordinaryGovShare   int64 = ordinaryFeeAmount / 2
	largeFeeAmount     int64 = 4_000_000_000_000_000_000
	largeGovShare      int64 = largeFeeAmount / 2
	cyclesAfterUpgrade       = 20

	legacyAmountBeforeOverflow int64 = 8_000_000_000_004_000_000
	wrappedAmountAfterFifth    int64 = -8_446_744_073_705_551_616
	wrappedAmountAfterTwenty   int64 = 3_106_511_852_584_896_768
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	feeSourceAddr = access.MustGetAddress(prbac.ROLE_STAKER.String())
	feeAddr       = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govAddr       = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr    = access.MustGetAddress(prbac.ROLE_DEVOPS.String())

	adminRealm     = testing.NewUserRealm(adminAddr)
	feeSourceRealm = testing.NewUserRealm(feeSourceAddr)
	userAddr       = testutils.TestAddress("gov-upgrade-user")
	userRealm      = testing.NewUserRealm(userAddr)
	devOpsRealm    = testing.NewUserRealm(devOpsAddr)
)

func main(cur realm) {
	println("[SCENARIO] 1. Start with legacy implementations and settle a completed fee claim")
	beforeSupply := bar.TotalSupply()
	beforeSource := bar.BalanceOf(feeSourceAddr)
	beforeUser := bar.BalanceOf(userAddr)
	beforeDevOps := bar.BalanceOf(devOpsAddr)
	beforeGov := bar.BalanceOf(govAddr)
	beforeFeeAddress := bar.BalanceOf(feeAddr)

	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), protocolFeeLegacyPath)
	govStaker.UpgradeImpl(cross(cur), govStakerLegacyPath)
	protocolFee.SetDevOpsPct(cross(cur), 5_000)
	bar.Mint(cross(cur), feeSourceAddr, largeFeeAmount+4*ordinaryFeeAmount)
	gns.Transfer(cross(cur), userAddr, 2_000_000)

	testing.SetRealm(userRealm)
	gns.Approve(cross(cur), govAddr, 1_000_000)
	govStaker.Delegate(cross(cur), adminAddr, 1_000_000, "")
	uassert.Equal(t, int64(1_000_000), govStaker.GetTotalDelegated())

	addFee(cur, ordinaryFeeAmount)
	claimExact(cur, ordinaryGovShare)
	uassert.Equal(t, ordinaryGovShare, govStaker.GetProtocolFeeAmount(barTokenPath))
	println("[EXPECTED] completed legacy claim: 1000000")

	println("[SCENARIO] 2. Preserve a pending epoch and prior claim across legacy-to-v1 gov/staker UpgradeImpl")
	gns.Approve(cross(cur), govAddr, 1_000_000)
	govStaker.Delegate(cross(cur), adminAddr, 1_000_000, "")
	addFee(cur, ordinaryFeeAmount)

	pendingBefore := claimableProtocolFee(userAddr)
	pendingEpochsBefore, pendingAmountsBefore := protocolFee.GetAccrualBuckets(barTokenPath, 0)
	uassert.Equal(t, ordinaryGovShare, pendingBefore)
	uassert.Equal(t, 1, len(pendingEpochsBefore))
	uassert.Equal(t, ordinaryGovShare, pendingAmountsBefore[0])
	uassert.Equal(t, int64(2_000_000), govStaker.GetTotalDelegated())

	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerV1Path)
	uassert.Equal(t, govStakerV1Path, govStaker.GetImplementationPackagePath())
	uassert.Equal(t, int64(2_000_000), govStaker.GetTotalDelegated())
	uassert.Equal(t, ordinaryGovShare, govStaker.GetProtocolFeeAmount(barTokenPath))
	uassert.Equal(t, pendingBefore, claimableProtocolFee(userAddr))
	pendingEpochsAfter, pendingAmountsAfter := protocolFee.GetAccrualBuckets(barTokenPath, 0)
	uassert.Equal(t, len(pendingEpochsBefore), len(pendingEpochsAfter))
	uassert.Equal(t, pendingEpochsBefore[0], pendingEpochsAfter[0])
	uassert.Equal(t, pendingAmountsBefore[0], pendingAmountsAfter[0])
	println("[EXPECTED] pending fee before/after gov upgrade: 1000000 / 1000000")
	println("[EXPECTED] delegated stake after gov upgrade: 2000000")

	claimExact(cur, ordinaryGovShare)
	uassert.Equal(t, int64(2_000_000), govStaker.GetProtocolFeeAmount(barTokenPath))
	uassert.Equal(t, int64(0), claimableProtocolFee(userAddr))

	println("[SCENARIO] 3. Legacy protocol_fee with v1 gov/staker at ordinary totals")
	testing.SetRealm(adminRealm)
	uassert.Equal(t, protocolFeeLegacyPath, protocolFee.GetImplementationPackagePath())
	addFee(cur, ordinaryFeeAmount)
	claimExact(cur, ordinaryGovShare)
	uassert.Equal(t, int64(3_000_000), govStaker.GetProtocolFeeAmount(barTokenPath))
	println("[EXPECTED] legacy protocol_fee / v1 gov/staker payout: 1000000")

	println("[SCENARIO] 4. Patched protocol_fee with legacy gov/staker at ordinary totals")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerLegacyPath)
	protocolFee.UpgradeImpl(cross(cur), protocolFeeV1Path)
	uassert.Equal(t, govStakerLegacyPath, govStaker.GetImplementationPackagePath())
	uassert.Equal(t, protocolFeeV1Path, protocolFee.GetImplementationPackagePath())
	addFee(cur, ordinaryFeeAmount)
	claimExact(cur, ordinaryGovShare)
	uassert.Equal(t, int64(4_000_000), govStaker.GetProtocolFeeAmount(barTokenPath))
	println("[EXPECTED] v1 protocol_fee / legacy gov/staker payout: 1000000")

	println("[SCENARIO] 5. Upgrade gov/staker before folding fees across the signed boundary")
	for i := 0; i < 4; i++ {
		addFee(cur, largeFeeAmount)
		claimAndRecycleLargeFee(cur)
	}
	uassert.Equal(t, legacyAmountBeforeOverflow, govStaker.GetProtocolFeeAmount(barTokenPath))
	addFee(cur, largeFeeAmount)
	pendingEpochs, pendingAmounts := protocolFee.GetAccrualBuckets(barTokenPath, 0)
	uassert.Equal(t, 1, len(pendingEpochs))
	uassert.Equal(t, largeGovShare, pendingAmounts[0])

	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross(cur), govStakerV1Path)
	uassert.Equal(t, govStakerV1Path, govStaker.GetImplementationPackagePath())
	uassert.Equal(t, int64(2_000_000), govStaker.GetTotalDelegated())
	uassert.Equal(t, legacyAmountBeforeOverflow, govStaker.GetProtocolFeeAmount(barTokenPath))
	uassert.Equal(t, largeGovShare, claimableProtocolFee(userAddr))
	println("[EXPECTED] pending reward after patched gov upgrade: 2000000000000000000")

	claimAndRecycleLargeFee(cur)
	uassert.Equal(t, wrappedAmountAfterFifth, govStaker.GetProtocolFeeAmount(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterFifth, protocolFee.GetAccuTransferToGovStakerByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterFifth, protocolFee.GetActualDistributedToGovStakerByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterFifth, protocolFee.GetAccuTransferToDevOpsByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterFifth, protocolFee.GetActualDistributedToDevOpsByTokenPath(barTokenPath))

	println("[SCENARIO] 6. Keep both patched implementations live across further fee-counter rollovers")
	for i := 5; i < cyclesAfterUpgrade; i++ {
		addFee(cur, largeFeeAmount)
		claimAndRecycleLargeFee(cur)
	}

	uassert.Equal(t, wrappedAmountAfterTwenty, govStaker.GetProtocolFeeAmount(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterTwenty, protocolFee.GetAccuTransferToGovStakerByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterTwenty, protocolFee.GetActualDistributedToGovStakerByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterTwenty, protocolFee.GetAccuTransferToDevOpsByTokenPath(barTokenPath))
	uassert.Equal(t, wrappedAmountAfterTwenty, protocolFee.GetActualDistributedToDevOpsByTokenPath(barTokenPath))
	uassert.Equal(t, 0, len(protocolFee.GetAccrualPendingTokens()))
	uassert.Equal(t, 0, len(protocolFee.GetReservedTokens()))
	uassert.Equal(t, beforeSupply+largeFeeAmount+4*ordinaryFeeAmount, bar.TotalSupply())
	uassert.Equal(t, largeFeeAmount, bar.BalanceOf(feeSourceAddr)-beforeSource)
	uassert.Equal(t, int64(4_000_000), bar.BalanceOf(userAddr)-beforeUser)
	uassert.Equal(t, int64(4_000_000), bar.BalanceOf(devOpsAddr)-beforeDevOps)
	uassert.Equal(t, int64(0), bar.BalanceOf(govAddr)-beforeGov)
	uassert.Equal(t, int64(0), bar.BalanceOf(feeAddr)-beforeFeeAddress)
	uassert.Equal(t, govStakerV1Path, govStaker.GetImplementationPackagePath())
	uassert.Equal(t, protocolFeeV1Path, protocolFee.GetImplementationPackagePath())
	println("[EXPECTED] 20 recycled 4e18 fee cycles: exact 2e18 payouts, no duplicates, wrapped totals 3106511852584896768")
}

func addFee(cur realm, amount int64) {
	testing.SetRealm(feeSourceRealm)
	bar.Approve(cross(cur), feeAddr, amount)
	if err := protocolFee.AddToProtocolFee(cross(cur), barTokenPath, amount); err != nil {
		panic(err.Error())
	}
}

func claimExact(cur realm, expected int64) {
	testing.SetRealm(userRealm)
	before := bar.BalanceOf(userAddr)
	govStaker.CollectProtocolFeeReward(cross(cur), barTokenPath)
	after := bar.BalanceOf(userAddr)
	uassert.Equal(t, expected, after-before)

	// The same claim must be idempotent: no accrued amount can be paid twice.
	govStaker.CollectProtocolFeeReward(cross(cur), barTokenPath)
	uassert.Equal(t, after, bar.BalanceOf(userAddr))
}

func claimAndRecycleLargeFee(cur realm) {
	claimExact(cur, largeGovShare)

	testing.SetRealm(userRealm)
	bar.Transfer(cross(cur), feeSourceAddr, largeGovShare)
	testing.SetRealm(devOpsRealm)
	bar.Transfer(cross(cur), feeSourceAddr, largeGovShare)
}

func claimableProtocolFee(addr address) int64 {
	_, rewards, err := govStaker.GetClaimableRewardByAddress(addr)
	if err != nil {
		panic(err.Error())
	}
	return rewards[barTokenPath]
}

// Output:
// [SCENARIO] 1. Start with legacy implementations and settle a completed fee claim
// [EXPECTED] completed legacy claim: 1000000
// [SCENARIO] 2. Preserve a pending epoch and prior claim across legacy-to-v1 gov/staker UpgradeImpl
// [EXPECTED] pending fee before/after gov upgrade: 1000000 / 1000000
// [EXPECTED] delegated stake after gov upgrade: 2000000
// [SCENARIO] 3. Legacy protocol_fee with v1 gov/staker at ordinary totals
// [EXPECTED] legacy protocol_fee / v1 gov/staker payout: 1000000
// [SCENARIO] 4. Patched protocol_fee with legacy gov/staker at ordinary totals
// [EXPECTED] v1 protocol_fee / legacy gov/staker payout: 1000000
// [SCENARIO] 5. Upgrade gov/staker before folding fees across the signed boundary
// [EXPECTED] pending reward after patched gov upgrade: 2000000000000000000
// [SCENARIO] 6. Keep both patched implementations live across further fee-counter rollovers
// [EXPECTED] 20 recycled 4e18 fee cycles: exact 2e18 payouts, no duplicates, wrapped totals 3106511852584896768
