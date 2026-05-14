// launchpad contract caller lifecycle test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/eth"
)

const contractPackagePath = "gno.land/r/test/contract"

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	contractAddr  = chain.PackageAddress(contractPackagePath)
	contractRealm = testing.NewCodeRealm(contractPackagePath)

	projectAddr = testutils.TestAddress("project1")

	blockTime = int64(5)
)

func main() {
	println("[SCENARIO] 1. Create launchpad project")
	projectId := createETHProject()
	projectTier30 := projectId + ":30"
	println()

	println("[SCENARIO] 2. Contract deposits GNS in project tier30")
	testing.SkipHeights(60 * 60 * 24 * 3 / blockTime)
	depositId := depositGnsFromContract(projectTier30, 1_000_000)
	println()

	println("[SCENARIO] 3. Skip blocks to end project")
	testing.SkipHeights(60 * 60 * 24 * 27 / blockTime)
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Contract collects reward and withdraws GNS")
	collectRewardAndWithdrawFromContract(depositId)
	println()
}

func createETHProject() string {
	println("[INFO] Creating ETH launchpad project")

	rewardAmount := int64(10_000_000)
	secondsOf7Days := int64(60 * 60 * 24 * 7)
	startTime := time.Now().Unix() + secondsOf7Days

	println("[INFO] Admin creating ETH project")
	testing.SetRealm(adminRealm)
	eth.Approve(cross, launchpadAddr, rewardAmount)
	projectId := launchpad.CreateProject(
		cross,
		"Test ETH Project",
		"gno.land/r/gnoswap/test_token/eth",
		projectAddr,
		rewardAmount,
		"",
		"",
		30,
		30,
		40,
		startTime,
	)

	ufmt.Printf("[INFO] Skipping %d blocks to activate project\n", secondsOf7Days/blockTime)
	testing.SkipHeights(secondsOf7Days / blockTime)

	println("[EXPECTED] Project created with ID:", projectId)
	return projectId
}

func depositGnsFromContract(projectTierId string, depositAmount int64) string {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, contractAddr, depositAmount)

	testing.SetRealm(contractRealm)
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(cross, projectTierId, depositAmount, "")

	testing.SetRealm(launchpadRealm)
	deposit, _ := launchpad.GetDeposit(depositId)
	if deposit.Depositor() != contractAddr {
		panic("deposit depositor is not contract")
	}

	ufmt.Printf("[EXPECTED] Contract deposit created with ID: %s\n", depositId)
	println("[EXPECTED] Deposit depositor is contract: true")
	return depositId
}

func collectRewardAndWithdrawFromContract(depositId string) {
	testing.SetRealm(contractRealm)

	beforeEthBalance := eth.BalanceOf(contractAddr)
	beforeGnsBalance := gns.BalanceOf(contractAddr)
	rewardAmount := launchpad.CollectRewardByDepositId(cross, depositId)
	gnsAmount, err := launchpad.CollectDepositGns(cross, depositId)
	if err != nil {
		panic(err)
	}
	afterEthBalance := eth.BalanceOf(contractAddr)
	afterGnsBalance := gns.BalanceOf(contractAddr)

	if rewardAmount <= 0 {
		panic("contract reward amount is zero")
	}
	if gnsAmount != 1_000_000 {
		panic("contract withdraw amount mismatch")
	}

	ufmt.Printf("[EXPECTED] Contract reward amount: %d\n", rewardAmount)
	ufmt.Printf("[EXPECTED] Contract ETH balance delta: %d\n", afterEthBalance-beforeEthBalance)
	ufmt.Printf("[EXPECTED] Contract GNS balance delta: %d\n", afterGnsBalance-beforeGnsBalance)
}

// Output:
// [SCENARIO] 1. Create launchpad project
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 120960 blocks to activate project
// [EXPECTED] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
//
// [SCENARIO] 2. Contract deposits GNS in project tier30
// [EXPECTED] Contract deposit created with ID: 1
// [EXPECTED] Deposit depositor is contract: true
//
// [SCENARIO] 3. Skip blocks to end project
//
// [SCENARIO] 4. Contract collects reward and withdraws GNS
// [EXPECTED] Contract reward amount: 2999999
// [EXPECTED] Contract ETH balance delta: 2999999
// [EXPECTED] Contract GNS balance delta: 1000000
