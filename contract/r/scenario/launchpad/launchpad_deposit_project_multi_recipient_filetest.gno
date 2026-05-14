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

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	testutils "gno.land/p/nt/testutils/v0"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/sol"
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
	println("[SCENARIO] 1. Create ETH launchpad project")
	createETHProject()
	projectId := "gno.land/r/gnoswap/test_token/eth:123"
	projectTier30Id := "gno.land/r/gnoswap/test_token/eth:123:30"
	println()

	// [SCENARIO] 2. Protocol fee setup
	println("[SCENARIO] 2. Protocol fee setup")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 3. Deposit GNS to ETH project tier 30
	println("[SCENARIO] 3. Deposit GNS to ETH project tier 30 by user1")
	depositGnsTo(aliceAddr, projectId, projectTier30Id, 1_000_000)
	println()

	println("[SCENARIO] 4. Deposit GNS to ETH project tier 30 by user2")
	depositGnsTo(bobAddr, projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 5. Protocol fee setup 2
	println("[SCENARIO] 5. Protocol fee setup 2")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 6. Collect protocol fee for ETH project recipient
	println("[SCENARIO] 6. Collect protocol fee for ETH project recipient")
	collectProtocolFeeForETHProjectRecipient()
	println()

	// [SCENARIO] 7. Deposit GNS to ETH project tier 30 again
	println("[SCENARIO] 7. Deposit GNS to ETH project tier 30 again")
	depositGnsTo(aliceAddr, projectId, projectTier30Id, 1_000_000)
	depositGnsTo(bobAddr, projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 8. Protocol fee setup 3
	println("[SCENARIO] 8. Protocol fee setup 3")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 9. Collect protocol fee for ETH project recipient 2
	println("[SCENARIO] 9. Collect protocol fee for ETH project recipient 2")
	collectProtocolFeeForETHProjectRecipient2()
	println()
}

// Create ETH launchpad project
func createETHProject() {
	println("[INFO] Creating ETH launchpad project")

	recipientAddr := testutils.TestAddress("project-owner")
	projectName := "ETH Launchpad Project"
	rewardTokenPath := "gno.land/r/gnoswap/test_token/eth"
	rewardAmount := int64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := int64(10)
	tier90Ratio := int64(20)
	tier180Ratio := int64(70)
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	println("[INFO] Admin creating ETH project")
	testing.SetRealm(adminRealm)
	eth.Approve(cross, launchpadAddr, int64(rewardAmount))
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
func setupProtocolFee(atomAmount, solAmount int64) {
	println("[INFO] Setting up mock protocol fees")
	// admin > staker, protocol_fee pulls from caller via TransferFrom
	println("[INFO] Admin transferring tokens to staker caller")
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	println("[INFO] Adding tokens to protocol fee")
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)
	testing.SkipHeights(1)

	println("[INFO] Validating protocol fee balances")
	println("[EXPECTED] Atom balance:", atom.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Sol balance:", sol.BalanceOf(protocolFeeAddr))

	testing.SetRealm(govStakerRealm)
	reservedTokens := protocol_fee.GetReservedTokens()
	println("[EXPECTED] Reserved protocol fee token count:", len(reservedTokens))
}

// Deposit GNS to ETH project tier 30
func depositGnsTo(toAddress address, projectId, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Depositing GNS to ETH project tier 30")

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

// Collect protocol fee for ETH project recipient
func collectProtocolFeeForETHProjectRecipient() {
	testing.SetRealm(projectRealm)

	// protocol fee has atom, sol
	println("[INFO] Atom balance in protocol fee:", atom.BalanceOf(protocolFeeAddr))
	println("[INFO] Sol balance in protocol fee:", sol.BalanceOf(protocolFeeAddr))

	testing.SetRealm(projectRealm)
	staker.CollectReward(cross)
	launchpad.CollectProtocolFee(cross)

	// 1000 + 1000 - 499 = 1501
	// 2500 + 2500 - 1249 = 3751
	println("[EXPECTED] Gov staker atom balance after collection:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] Gov staker sol balance after collection:", sol.BalanceOf(govStakerAddr))

	// 1000 / 2 * 1 = 500
	// 2500 / 2 * 1 = 1250
	println("[EXPECTED] Project atom balance after collection:", atom.BalanceOf(projectAddr))
	println("[EXPECTED] Project sol balance after collection:", sol.BalanceOf(projectAddr))
}

// Collect protocol fee for ETH project recipient 2
func collectProtocolFeeForETHProjectRecipient2() {
	testing.SetRealm(projectRealm)

	// protocol fee has atom, sol
	println("[INFO] Atom balance in protocol fee:", atom.BalanceOf(protocolFeeAddr))
	println("[INFO] Sol balance in protocol fee:", sol.BalanceOf(protocolFeeAddr))
	testing.SkipHeights(1)

	launchpad.CollectProtocolFee(cross)

	// 1501 + 1000 = 2501
	// 3751 + 2500 = 6251
	println("[EXPECTED] Gov staker atom balance after collection:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] Gov staker sol balance after collection:", sol.BalanceOf(govStakerAddr))

	println("[EXPECTED] Project atom balance after collection:", atom.BalanceOf(projectAddr))
	println("[EXPECTED] Project sol balance after collection:", sol.BalanceOf(projectAddr))

	testing.SkipHeights(1)
}

// Output:
// [SCENARIO] 1. Create ETH launchpad project
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 120960 blocks
// [EXPECTED] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
// [EXPECTED] Project name: ETH Launchpad Project
// [EXPECTED] Project token path: gno.land/r/gnoswap/test_token/eth
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
// [INFO] Admin transferring tokens to staker caller
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Atom balance: 1000
// [EXPECTED] Sol balance: 2500
// [EXPECTED] Reserved protocol fee token count: 2
//
// [SCENARIO] 3. Deposit GNS to ETH project tier 30 by user1
// [INFO] Depositing GNS to ETH project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 1
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 4. Deposit GNS to ETH project tier 30 by user2
// [INFO] Depositing GNS to ETH project tier 30
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
// [INFO] Admin transferring tokens to staker caller
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Atom balance: 1000
// [EXPECTED] Sol balance: 2500
// [EXPECTED] Reserved protocol fee token count: 2
//
// [SCENARIO] 6. Collect protocol fee for ETH project recipient
// [INFO] Atom balance in protocol fee: 1000
// [INFO] Sol balance in protocol fee: 2500
// [EXPECTED] Gov staker atom balance after collection: 1501
// [EXPECTED] Gov staker sol balance after collection: 3751
// [EXPECTED] Project atom balance after collection: 499
// [EXPECTED] Project sol balance after collection: 1249
//
// [SCENARIO] 7. Deposit GNS to ETH project tier 30 again
// [INFO] Depositing GNS to ETH project tier 30
// [INFO] Admin transferring GNS to depositor for deposit
// [INFO] Depositor delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: 3
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [INFO] Depositing GNS to ETH project tier 30
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
// [INFO] Admin transferring tokens to staker caller
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Atom balance: 1000
// [EXPECTED] Sol balance: 2500
// [EXPECTED] Reserved protocol fee token count: 2
//
// [SCENARIO] 9. Collect protocol fee for ETH project recipient 2
// [INFO] Atom balance in protocol fee: 1000
// [INFO] Sol balance in protocol fee: 2500
// [EXPECTED] Gov staker atom balance after collection: 2002
// [EXPECTED] Gov staker sol balance after collection: 5002
// [EXPECTED] Project atom balance after collection: 998
// [EXPECTED] Project sol balance after collection: 2498
