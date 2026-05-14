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
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/sol"
)

const contractProjectPackagePath = "gno.land/r/test/contract"

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

func main() {
	println("[SCENARIO] 1. Create launchpad project for contract recipient")
	projectId := createContractRecipientProject()
	projectTier30Id := projectId + ":30"
	println()

	println("[SCENARIO] 2. Alice deposits GNS into contract-owned project")
	depositGnsForContractProject(projectTier30Id, 1_000_000)
	println()

	println("[SCENARIO] 3. Add and distribute protocol fees")
	addProtocolFeesForContractProject(500, 1000)
	distributeProtocolFeesForContractProject()
	println()

	println("[SCENARIO] 4. Contract project recipient collects protocol fee")
	collectProtocolFeesAsContractProjectRecipient()
	println()
}

func createContractRecipientProject() string {
	println("[INFO] Creating ETH launchpad project")

	rewardAmount := int64(10_000_000)
	secondsOf7Days := int64(60 * 60 * 24 * 7)
	startTime := time.Now().Unix() + secondsOf7Days

	println("[INFO] Admin creating project with contract recipient")
	testing.SetRealm(adminRealm)
	eth.Approve(cross, launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross,
		"Contract Recipient ETH Project",
		"gno.land/r/gnoswap/test_token/eth",
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

func depositGnsForContractProject(projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, aliceAddr, depositAmount)

	testing.SetRealm(testing.NewUserRealm(aliceAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")

	ufmt.Printf("[EXPECTED] Deposit created with ID: %s\n", depositId)
	ufmt.Printf("[EXPECTED] Deposit amount: %d\n", depositAmount)
	testing.SkipHeights(1)
}

func addProtocolFeesForContractProject(atomAmount, solAmount int64) {
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)

	ufmt.Printf("[INFO] Protocol fee added - ATOM: %d, SOL: %d\n", atomAmount, solAmount)
	testing.SkipHeights(1)
}

func distributeProtocolFeesForContractProject() {
	testing.SetRealm(govStakerRealm)
	protocol_fee.DistributeProtocolFee(cross)

	println("[INFO] Protocol fee distributed")
	testing.SkipHeights(1)
}

func collectProtocolFeesAsContractProjectRecipient() {
	testing.SetRealm(govStakerRealm)
	emissionReward, protocolFeeRewards, _ := staker.GetClaimableRewardByLaunchpad(contractProjectAddr)
	ufmt.Printf("[INFO] claimable reward (contract recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatContractProjectProtocolFees(protocolFeeRewards))

	testing.SetRealm(contractProjectRealm)
	prevAtomBalance := atom.BalanceOf(contractProjectAddr)
	prevSolBalance := sol.BalanceOf(contractProjectAddr)
	launchpad.CollectProtocolFee(cross)
	afterAtomBalance := atom.BalanceOf(contractProjectAddr)
	afterSolBalance := sol.BalanceOf(contractProjectAddr)

	if afterAtomBalance <= prevAtomBalance {
		panic("contract ATOM balance did not increase")
	}
	if afterSolBalance <= prevSolBalance {
		panic("contract SOL balance did not increase")
	}

	ufmt.Printf("[EXPECTED] Contract ATOM balance delta: %d\n", afterAtomBalance-prevAtomBalance)
	ufmt.Printf("[EXPECTED] Contract SOL balance delta: %d\n", afterSolBalance-prevSolBalance)
}

func formatContractProjectProtocolFees(fees map[string]int64) string {
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
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating project with contract recipient
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
// [EXPECTED] Project recipient is contract: true
//
// [SCENARIO] 2. Alice deposits GNS into contract-owned project
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Deposit amount: 1000000
//
// [SCENARIO] 3. Add and distribute protocol fees
// [INFO] Protocol fee added - ATOM: 500, SOL: 1000
// [INFO] Protocol fee distributed
//
// [SCENARIO] 4. Contract project recipient collects protocol fee
// [INFO] claimable reward (contract recipient): emissionReward=0, protocolFees=map[gno.land/r/gnoswap/test_token/atom:499 gno.land/r/gnoswap/test_token/sol:999]
// [EXPECTED] Contract ATOM balance delta: 499
// [EXPECTED] Contract SOL balance delta: 999
