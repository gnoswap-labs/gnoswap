// launchpad contract project protocol fee lifecycle test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	contractProjectPackagePath = "gno.land/r/test/contract"
	barPath                    = "gno.land/r/onbloc/bar.BAR"
	quxPath                    = "gno.land/r/onbloc/qux.QUX"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _   = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)

	aliceAddr = testutils.TestAddress("alice")

	contractProjectAddr  = chain.PackageAddress(contractProjectPackagePath)
	contractProjectRealm = testing.NewCodeRealm(contractProjectPackagePath)
)

func main(cur realm) {
	println("[SCENARIO] 1. Create launchpad project for contract recipient")
	projectId := createContractRecipientProject(cur)
	projectTier30Id := projectId + ":30"
	println()

	println("[SCENARIO] 2. Alice deposits GNS into contract-owned project")
	depositGnsForContractProject(cur, projectTier30Id, 1_000_000)
	println()

	println("[SCENARIO] 3. Add and distribute protocol fees")
	addProtocolFeesForContractProject(cur, 500, 1000)
	distributeProtocolFeesForContractProject(cur)
	println()

	println("[SCENARIO] 4. Contract project recipient collects protocol fee")
	collectProtocolFeesAsContractProjectRecipient(cur)
	println()
}

func createContractRecipientProject(cur realm) string {
	println("[INFO] Creating OBL launchpad project")

	rewardAmount := int64(10_000_000)
	secondsOf7Days := int64(60 * 60 * 24 * 7)
	startTime := time.Now().Unix() + secondsOf7Days

	println("[INFO] Admin creating project with contract recipient")
	testing.SetRealm(adminRealm)
	obl.Approve(cross(cur), launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross(cur),
		"Contract Recipient OBL Project",
		"gno.land/r/onbloc/obl.OBL",
		contractProjectAddr,
		rewardAmount,
		"",
		"",
		30,
		30,
		40,
		startTime,
	)

	ufmt.Printf("[INFO] Skipping %d blocks to activate project\n", secondsOf7Days/5)
	testing.SkipHeights(secondsOf7Days / 5)

	testing.SetRealm(launchpadRealm)
	project, _ := launchpad.GetProject(projectId)
	if project.Recipient() != contractProjectAddr {
		panic("project recipient is not contract")
	}

	println("[EXPECTED] Project created with ID:", projectId)
	println("[EXPECTED] Project recipient is contract: true")
	return projectId
}

func depositGnsForContractProject(cur realm, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, depositAmount)

	testing.SetRealm(testing.NewUserRealm(aliceAddr))
	gns.Approve(cross(cur), launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(cross(cur), projectTierId, depositAmount, "")

	ufmt.Printf("[EXPECTED] Deposit created with ID: %s\n", depositId)
	ufmt.Printf("[EXPECTED] Deposit amount: %d\n", depositAmount)
	testing.SkipHeights(1)
}

func addProtocolFeesForContractProject(cur realm, barAmount, quxAmount int64) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, barAmount)
	qux.Transfer(cross(cur), stakerAddr, quxAmount)

	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, barAmount)
	qux.Approve(cross(cur), protocolFeeAddr, quxAmount)
	protocol_fee.AddToProtocolFee(cross(cur), barPath, barAmount)
	protocol_fee.AddToProtocolFee(cross(cur), quxPath, quxAmount)

	ufmt.Printf("[INFO] Protocol fee added - BAR: %d, QUX: %d\n", barAmount, quxAmount)
	testing.SkipHeights(1)
}

func distributeProtocolFeesForContractProject(cur realm) {
	testing.SetRealm(govStakerRealm)
	protocol_fee.DistributeProtocolFee(cross(cur))

	println("[INFO] Protocol fee distributed")
	testing.SkipHeights(1)
}

func collectProtocolFeesAsContractProjectRecipient(cur realm) {
	testing.SetRealm(govStakerRealm)
	emissionReward, protocolFeeRewards, _ := staker.GetClaimableRewardByLaunchpad(contractProjectAddr)
	ufmt.Printf("[INFO] claimable reward (contract recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatContractProjectProtocolFees(cur, protocolFeeRewards))

	testing.SetRealm(contractProjectRealm)
	collectProtocolFeeRewardAndCheck(cur, barPath, 499, 0)
	checkClaimableProtocolFees(cur, 0, 999)
	collectProtocolFeeRewardAndCheck(cur, barPath, 0, 0)
	checkClaimableProtocolFees(cur, 0, 999)
	collectProtocolFeeAndCheck(cur, 0, 999)
}

func collectProtocolFeeRewardAndCheck(cur realm, tokenPath string, expectedBar, expectedQux int64) {
	prevBarBalance := bar.BalanceOf(contractProjectAddr)
	prevQuxBalance := qux.BalanceOf(contractProjectAddr)
	launchpad.CollectProtocolFeeReward(cross(cur), tokenPath)
	assertInt64Equal(cur, bar.BalanceOf(contractProjectAddr)-prevBarBalance, expectedBar, "contract BAR balance delta")
	assertInt64Equal(cur, qux.BalanceOf(contractProjectAddr)-prevQuxBalance, expectedQux, "contract QUX balance delta")
	ufmt.Printf("[EXPECTED] Contract BAR balance delta: %d\n", bar.BalanceOf(contractProjectAddr)-prevBarBalance)
	ufmt.Printf("[EXPECTED] Contract QUX balance delta: %d\n", qux.BalanceOf(contractProjectAddr)-prevQuxBalance)
}

func collectProtocolFeeAndCheck(cur realm, expectedBar, expectedQux int64) {
	prevBarBalance := bar.BalanceOf(contractProjectAddr)
	prevQuxBalance := qux.BalanceOf(contractProjectAddr)
	launchpad.CollectProtocolFee(cross(cur))
	assertInt64Equal(cur, bar.BalanceOf(contractProjectAddr)-prevBarBalance, expectedBar, "contract BAR balance delta")
	assertInt64Equal(cur, qux.BalanceOf(contractProjectAddr)-prevQuxBalance, expectedQux, "contract QUX balance delta")
	ufmt.Printf("[EXPECTED] Contract BAR balance delta: %d\n", bar.BalanceOf(contractProjectAddr)-prevBarBalance)
	ufmt.Printf("[EXPECTED] Contract QUX balance delta: %d\n", qux.BalanceOf(contractProjectAddr)-prevQuxBalance)
}

func checkClaimableProtocolFees(cur realm, expectedBar, expectedQux int64) {
	testing.SetRealm(govStakerRealm)
	_, protocolFeeRewards, _ := staker.GetClaimableRewardByLaunchpad(contractProjectAddr)
	assertInt64Equal(cur, protocolFeeRewards[barPath], expectedBar, "contract claimable BAR")
	assertInt64Equal(cur, protocolFeeRewards[quxPath], expectedQux, "contract claimable QUX")
	ufmt.Printf("[EXPECTED] Contract claimable BAR: %d\n", protocolFeeRewards[barPath])
	ufmt.Printf("[EXPECTED] Contract claimable QUX: %d\n", protocolFeeRewards[quxPath])
	testing.SetRealm(contractProjectRealm)
}

func assertInt64Equal(cur realm, actual, expected int64, label string) {
	if actual != expected {
		panic(ufmt.Sprintf("%s mismatch: expected %d, got %d", label, expected, actual))
	}
}

func formatContractProjectProtocolFees(cur realm, fees map[string]int64) string {
	if len(fees) == 0 {
		return "map[]"
	}

	result := "map["
	first := true
	for k, v := range fees {
		if !first {
			result += " "
		}
		result += k + ":" + ufmt.Sprintf("%d", v)
		first = false
	}
	result += "]"
	return result
}

// Output:
// [SCENARIO] 1. Create launchpad project for contract recipient
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating project with contract recipient
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl.OBL:123
// [EXPECTED] Project recipient is contract: true
//
// [SCENARIO] 2. Alice deposits GNS into contract-owned project
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Deposit amount: 1000000
//
// [SCENARIO] 3. Add and distribute protocol fees
// [INFO] Protocol fee added - BAR: 500, QUX: 1000
// [INFO] Protocol fee distributed
//
// [SCENARIO] 4. Contract project recipient collects protocol fee
// [INFO] claimable reward (contract recipient): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar.BAR:499 gno.land/r/onbloc/qux.QUX:999]
// [EXPECTED] Contract BAR balance delta: 499
// [EXPECTED] Contract QUX balance delta: 0
// [EXPECTED] Contract claimable BAR: 0
// [EXPECTED] Contract claimable QUX: 999
// [EXPECTED] Contract BAR balance delta: 0
// [EXPECTED] Contract QUX balance delta: 0
// [EXPECTED] Contract claimable BAR: 0
// [EXPECTED] Contract claimable QUX: 999
// [EXPECTED] Contract BAR balance delta: 0
// [EXPECTED] Contract QUX balance delta: 999
