// launchpad deposit project single recipient

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/p/nt/testutils"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	launchpadRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/launchpad")

	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = testing.NewUserRealm(bobAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectId := "gno.land/r/onbloc/obl:123"
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println()

	// [SCENARIO] 2. Protocol fee setup
	println("[SCENARIO] 2. Protocol fee setup")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 3. Deposit GNS to OBL project tier 30
	println("[SCENARIO] 3. Deposit GNS to OBL project tier 30 by user1")
	depositGnsTo(aliceAddr, projectId, projectTier30Id, 1_000_000)
	println()

	println("[SCENARIO] 4. Deposit GNS to OBL project tier 30 by user2")
	depositGnsTo(bobAddr, projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 5. Protocol fee setup 2
	println("[SCENARIO] 5. Protocol fee setup 2")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 6. Collect protocol fee for OBL project recipient
	println("[SCENARIO] 6. Collect protocol fee for OBL project recipient")
	collectProtocolFeeForOBLProjectRecipient()
	println()

	// [SCENARIO] 7. Deposit GNS to OBL project tier 30 again
	println("[SCENARIO] 7. Deposit GNS to OBL project tier 30 again")
	depositGnsTo(aliceAddr, projectId, projectTier30Id, 1_000_000)
	depositGnsTo(bobAddr, projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 8. Protocol fee setup 3
	println("[SCENARIO] 8. Protocol fee setup 3")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 9. Collect protocol fee for OBL project recipient 2
	println("[SCENARIO] 9. Collect protocol fee for OBL project recipient 2")
	collectProtocolFeeForOBLProjectRecipient2()
	println()
}

// Create OBL launchpad project
func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := testutils.TestAddress("project-owner")
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := int64(10)
	tier90Ratio := int64(20)
	tier180Ratio := int64(70)
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	println("[INFO] Admin creating OBL project")
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, int64(rewardAmount))
	projectId := launchpad.CreateProject(
		cross,
		projectName,
		rewardTokenPath,
		recipientAddr,
		rewardAmount,
		conditionPath,
		conditionsAmount,
		tier30Ratio,  // 100000000
		tier90Ratio,  // 200000000
		tier180Ratio, // 700000000
		startTime,    // 5 block later
	)

	println("[INFO] Skipping 120960 blocks")
	testing.SkipHeights(120960)

	println("[EXPECTED] Project created with ID:", projectId)

	// [INFO] Validate project info
	testing.SetRealm(launchpadRealm)
	project, _ := launchpad.GetProject(projectId)
	println("[EXPECTED] Project name:", project.Name())
	println("[EXPECTED] Project token path:", project.TokenPath())
	println("[EXPECTED] Project deposit amount:", project.DepositAmount())
	tiersRatios := project.TiersRatios()
	println("[EXPECTED] Project tier30 ratio:", tiersRatios[30])
	println("[EXPECTED] Project tier90 ratio:", tiersRatios[90])
	println("[EXPECTED] Project tier180 ratio:", tiersRatios[180])

	// [INFO] Validate tier info
	tier30, _ := launchpad.GetProjectTier(projectId, 30)
	println("[EXPECTED] Tier 30 amount:", tier30.TotalDistributeAmount())

	tier90, _ := launchpad.GetProjectTier(projectId, 90)
	println("[EXPECTED] Tier 90 amount:", tier90.TotalDistributeAmount())

	tier180, _ := launchpad.GetProjectTier(projectId, 180)
	println("[EXPECTED] Tier 180 amount:", tier180.TotalDistributeAmount())
}

// Mock protocol fee setup
func setupProtocolFee(barAmount, quxAmount int64) {
	println("[INFO] Setting up mock protocol fees")

	// admin > protocol_fee
	// send qux, bar for testing
	println("[INFO] Admin transferring tokens to protocol fee")
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, barAmount)
	qux.Transfer(cross, protocolFeeAddr, quxAmount)

	println("[INFO] Adding tokens to protocol fee")
	testing.SetRealm(stakerRealm)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", barAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", quxAmount)
	testing.SkipHeights(1)

	println("[INFO] Validating protocol fee balances")
	println("[EXPECTED] Bar balance:", bar.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Qux balance:", qux.BalanceOf(protocolFeeAddr))

	testing.SetRealm(govStakerRealm)
	println("[EXPECTED] Bar amount in protocol fee:", protocol_fee.GetAmountOfToken("gno.land/r/onbloc/bar"))
	println("[EXPECTED] Qux amount in protocol fee:", protocol_fee.GetAmountOfToken("gno.land/r/onbloc/qux"))
}

// Deposit GNS to OBL project tier 30
func depositGnsTo(toAddress address, projectId, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Depositing GNS to OBL project tier 30")

	println("[INFO] Admin transferring GNS to depositor for deposit")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, toAddress, depositAmount*2) // to deposit

	// delegate gns to gov staker
	println("[INFO] Depositor delegating GNS to gov staker")
	testing.SetRealm(testing.NewUserRealm(toAddress))
	gns.Approve(cross, govStakerAddr, depositAmount)
	staker.Delegate(cross, toAddress, int64(depositAmount), "") // bob has xgns 1_000_000

	println("[INFO] Skipping blocks to make project active")
	testing.SkipHeights(4) // project is active
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		int64(depositAmount),
		"",
	)
	println("[EXPECTED] Deposit created with ID:", depositId)

	// validate deposit
	testing.SetRealm(launchpadRealm)
	deposit, _ := launchpad.GetDeposit(depositId)
	println("[EXPECTED] Deposit amount:", deposit.DepositAmount())
	println("[EXPECTED] Deposit tier:", deposit.Tier())
	println("[EXPECTED] Deposit depositor:", deposit.Depositor())

	testing.SkipHeights(1)
}

// Collect protocol fee for OBL project recipient
func collectProtocolFeeForOBLProjectRecipient() {
	testing.SetRealm(projectRealm)

	// protocol fee has bar, qux
	println("[INFO] Bar balance in protocol fee:", bar.BalanceOf(protocolFeeAddr))
	println("[INFO] Qux balance in protocol fee:", qux.BalanceOf(protocolFeeAddr))

	testing.SetRealm(projectRealm)
	staker.CollectReward(cross)
	launchpad.CollectProtocolFee(cross)

	// 1000 + 1000 - 499 = 1501
	// 2500 + 2500 - 1249 = 3751
	println("[EXPECTED] Gov staker bar balance after collection:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] Gov staker qux balance after collection:", qux.BalanceOf(govStakerAddr))

	// 1000 / 2 * 1 = 500
	// 2500 / 2 * 1 = 1250
	println("[EXPECTED] Project bar balance after collection:", bar.BalanceOf(projectAddr))
	println("[EXPECTED] Project qux balance after collection:", qux.BalanceOf(projectAddr))
}

// Collect protocol fee for OBL project recipient 2
func collectProtocolFeeForOBLProjectRecipient2() {
	testing.SetRealm(projectRealm)

	// protocol fee has bar, qux
	println("[INFO] Bar balance in protocol fee:", bar.BalanceOf(protocolFeeAddr))
	println("[INFO] Qux balance in protocol fee:", qux.BalanceOf(protocolFeeAddr))
	testing.SkipHeights(1)

	launchpad.CollectProtocolFee(cross)

	// 1501 + 1000 = 2501
	// 3751 + 2500 = 6251
	println("[EXPECTED] Gov staker bar balance after collection:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] Gov staker qux balance after collection:", qux.BalanceOf(govStakerAddr))

	println("[EXPECTED] Project bar balance after collection:", bar.BalanceOf(projectAddr))
	println("[EXPECTED] Project qux balance after collection:", qux.BalanceOf(projectAddr))

	testing.SkipHeights(1)
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: OBL Launchpad Project
// [EXPECTED] Project token path: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 1000000000
// [EXPECTED] Project tier30 ratio: 10
// [EXPECTED] Project tier90 ratio: 20
// [EXPECTED] Project tier180 ratio: 70
// [EXPECTED] Tier 30 amount: 100000000
// [EXPECTED] Tier 90 amount: 200000000
// [EXPECTED] Tier 180 amount: 700000000
//
// [SCENARIO] 2. Protocol fee setup
// [INFO] Setting up mock protocol fees
// [INFO] Admin transferring tokens to protocol fee
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Bar balance: 1000
// [EXPECTED] Qux balance: 2500
// [EXPECTED] Bar amount in protocol fee: 1000
// [EXPECTED] Qux amount in protocol fee: 2500
//
// [SCENARIO] 3. Deposit GNS to OBL project tier 30 by user1
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 4. Deposit GNS to OBL project tier 30 by user2
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 2
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 5. Protocol fee setup 2
// [INFO] Setting up mock protocol fees
// [INFO] Admin transferring tokens to protocol fee
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Bar balance: 1000
// [EXPECTED] Qux balance: 2500
// [EXPECTED] Bar amount in protocol fee: 1000
// [EXPECTED] Qux amount in protocol fee: 2500
//
// [SCENARIO] 6. Collect protocol fee for OBL project recipient
// [INFO] Bar balance in protocol fee: 1000
// [INFO] Qux balance in protocol fee: 2500
// [EXPECTED] Gov staker bar balance after collection: 1501
// [EXPECTED] Gov staker qux balance after collection: 3751
// [EXPECTED] Project bar balance after collection: 499
// [EXPECTED] Project qux balance after collection: 1249
//
// [SCENARIO] 7. Deposit GNS to OBL project tier 30 again
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 3
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 4
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 8. Protocol fee setup 3
// [INFO] Setting up mock protocol fees
// [INFO] Admin transferring tokens to protocol fee
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Bar balance: 1000
// [EXPECTED] Qux balance: 2500
// [EXPECTED] Bar amount in protocol fee: 1000
// [EXPECTED] Qux amount in protocol fee: 2500
//
// [SCENARIO] 9. Collect protocol fee for OBL project recipient 2
// [INFO] Bar balance in protocol fee: 1000
// [INFO] Qux balance in protocol fee: 2500
// [EXPECTED] Gov staker bar balance after collection: 2002
// [EXPECTED] Gov staker qux balance after collection: 5002
// [EXPECTED] Project bar balance after collection: 998
// [EXPECTED] Project qux balance after collection: 2498
