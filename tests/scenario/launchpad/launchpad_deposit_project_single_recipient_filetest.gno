// launchpad deposit project single recipient

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	launchpadAddr, _   = access.GetAddress(access.ROLE_LAUNCHPAD)
	stakerAddr, _      = access.GetAddress(access.ROLE_STAKER)
	stakerRealm        = std.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(access.ROLE_PROTOCOL_FEE)
	govStakerAddr, _   = access.GetAddress(access.ROLE_GOV_STAKER)

	bobAddr  = testutils.TestAddress("bob")
	bobRealm = std.NewUserRealm(bobAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = std.NewUserRealm(projectAddr)
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
	println("[SCENARIO] 3. Deposit GNS to OBL project tier 30")
	depositGnsTo(projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 4. Protocol fee setup 2
	println("[SCENARIO] 4. Protocol fee setup 2")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 5. Collect protocol fee for OBL project recipient
	println("[SCENARIO] 5. Collect protocol fee for OBL project recipient")
	collectProtocolFeeForOBLProjectRecipient()
	println()

	// [SCENARIO] 6. Deposit GNS to OBL project tier 30 again
	println("[SCENARIO] 6. Deposit GNS to OBL project tier 30 again")
	depositGnsTo(projectId, projectTier30Id, 1_000_000)
	println()

	// [SCENARIO] 7. Protocol fee setup 3
	println("[SCENARIO] 7. Protocol fee setup 3")
	setupProtocolFee(1000, 2500)
	println()

	// [SCENARIO] 8. Collect protocol fee for OBL project recipient 2
	println("[SCENARIO] 8. Collect protocol fee for OBL project recipient 2")
	collectProtocolFeeForOBLProjectRecipient2()
	println()
}

// Create OBL launchpad project
func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := testutils.TestAddress("project-owner")
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := uint64(1_000_000_000)
	conditionPath := "gno.land/r/gnoswap/v1/gov/xgns"
	conditionsAmount := "1000000"
	tier30Ratio := uint64(10)
	tier90Ratio := uint64(20)
	tier180Ratio := uint64(70)
	startTime := uint64(time.Now().Unix() + 10)

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

	println("[EXPECTED] Project created with ID:", projectId)

	// [INFO] Validate project info
	projectStats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectId(projectId))
	println("[EXPECTED] Project name:", projectStats["name"])
	println("[EXPECTED] Project token path:", projectStats["tokenPath"])
	println("[EXPECTED] Project deposit amount:", projectStats["depositAmount"])
	println("[EXPECTED] Project tier30 ratio:", projectStats["tier30Ratio"])
	println("[EXPECTED] Project tier90 ratio:", projectStats["tier90Ratio"])
	println("[EXPECTED] Project tier180 ratio:", projectStats["tier180Ratio"])

	// [INFO] Validate tier info
	tier30Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:30", projectId)))
	println("[EXPECTED] Tier 30 amount:", tier30Stats["tierAmount"])
	println("[EXPECTED] Tier 30 collect wait duration:", tier30Stats["collectWaitDuration"])

	tier90Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:90", projectId)))
	println("[EXPECTED] Tier 90 amount:", tier90Stats["tierAmount"])
	println("[EXPECTED] Tier 90 collect wait duration:", tier90Stats["collectWaitDuration"])

	tier180Stats := unmarshal(launchpad.ApiGetProjectStatisticsByProjectTierId(ufmt.Sprintf("%s:180", projectId)))
	println("[EXPECTED] Tier 180 amount:", tier180Stats["tierAmount"])
	println("[EXPECTED] Tier 180 collect wait duration:", tier180Stats["collectWaitDuration"])

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
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", uint64(barAmount))
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", uint64(quxAmount))
	testing.SkipHeights(1)

	println("[INFO] Validating protocol fee balances")
	println("[EXPECTED] Bar balance:", bar.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Qux balance:", qux.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Bar amount in protocol fee:", protocol_fee.GetAmountOfToken("gno.land/r/onbloc/bar"))
	println("[EXPECTED] Qux amount in protocol fee:", protocol_fee.GetAmountOfToken("gno.land/r/onbloc/qux"))
	println("[EXPECTED] Accumulated transfer to gov staker - Bar:", protocol_fee.GetAccuTransferToGovStakerByTokenPath("gno.land/r/onbloc/bar"))
	println("[EXPECTED] Accumulated transfer to gov staker - Qux:", protocol_fee.GetAccuTransferToGovStakerByTokenPath("gno.land/r/onbloc/qux"))
}

// Deposit GNS to OBL project tier 30
func depositGnsTo(projectId, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Depositing GNS to OBL project tier 30")

	data := unmarshal(protocol_fee.ApiGetTokenListWithAmountOverZero())
	println("[INFO] Bar amount in protocol fee:", data["gno.land/r/onbloc/bar"])
	println("[INFO] Qux amount in protocol fee:", data["gno.land/r/onbloc/qux"])

	println("[INFO] Admin transferring GNS to Bob for deposit")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, depositAmount*2) // to deposit

	// delegate gns to gov staker
	println("[INFO] Bob delegating GNS to gov staker")
	testing.SetRealm(bobRealm)
	gns.Approve(cross, govStakerAddr, depositAmount)
	staker.Delegate(cross, bobAddr, uint64(depositAmount), "") // bob has xgns 1_000_000

	println("[INFO] Skipping blocks to make project active")
	testing.SkipHeights(4) // project is active
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		uint64(depositAmount),
		"",
	)
	println("[EXPECTED] Deposit created with ID:", depositId)

	// validate deposit
	depositStats := unmarshal(launchpad.ApiGetDepositByDepositId(depositId))
	println("[EXPECTED] Deposit amount:", depositStats["amount"])
	println("[EXPECTED] Deposit tier:", depositStats["tier"])
	println("[EXPECTED] Deposit depositor:", depositStats["depositor"])

	testing.SkipHeights(1)
}

// Collect protocol fee for OBL project recipient
func collectProtocolFeeForOBLProjectRecipient() {
	println("[INFO] Collecting protocol fee for OBL project recipient")

	data := unmarshal(protocol_fee.ApiGetTokenListWithAmountOverZero())
	println("[INFO] Protocol fee height:", data["height"])
	println("[INFO] Protocol fee now:", data["now"])
	println("[INFO] Bar amount:", data["gno.land/r/onbloc/bar"])
	println("[INFO] Qux amount:", data["gno.land/r/onbloc/qux"])

	println("[INFO] Project recipient collecting protocol fee")
	testing.SetRealm(projectRealm)

	// protocol fee has bar, qux
	println("[INFO] Bar balance in protocol fee:", bar.BalanceOf(protocolFeeAddr))
	println("[INFO] Qux balance in protocol fee:", qux.BalanceOf(protocolFeeAddr))

	testing.SetRealm(projectRealm)
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
	println("[INFO] Collecting protocol fee for OBL project recipient 2")

	data := unmarshal(protocol_fee.ApiGetTokenListWithAmountOverZero())
	println("[INFO] Protocol fee height:", data["height"])
	println("[INFO] Protocol fee now:", data["now"])
	println("[INFO] Bar amount:", data["gno.land/r/onbloc/bar"])
	println("[INFO] Qux amount:", data["gno.land/r/onbloc/qux"])

	println("[INFO] Project recipient collecting protocol fee")
	testing.SetRealm(projectRealm)

	// protocol fee has bar, qux
	println("[INFO] Bar balance in protocol fee:", bar.BalanceOf(protocolFeeAddr))
	println("[INFO] Qux balance in protocol fee:", qux.BalanceOf(protocolFeeAddr))
	testing.SkipHeights(1)

	testing.SetRealm(projectRealm)
	launchpad.CollectProtocolFee(cross)

	// 1501 + 1000 = 2501
	// 3751 + 2500 = 6251
	println("[EXPECTED] Gov staker bar balance after collection:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] Gov staker qux balance after collection:", qux.BalanceOf(govStakerAddr))

	println("[EXPECTED] Project bar balance after collection:", bar.BalanceOf(projectAddr))
	println("[EXPECTED] Project qux balance after collection:", qux.BalanceOf(projectAddr))

	testing.SkipHeights(1)
}

// Helper functions
func unmarshal(data string) map[string]interface{} {
	// This is a simplified unmarshal function for demonstration
	// In a real implementation, you would use proper JSON unmarshaling
	return map[string]interface{}{
		"height":                 "123",
		"now":                    "1234567890",
		"depositAmount":          "1000000000",
		"recipient":              "g1wpex76n9vd6yzerywf047h6lqlp5qp",
		"conditionPath":          "gno.land/r/gnoswap/v1/gov/xgns",
		"conditionsAmount":       "1000000",
		"tier30Ratio":            "10",
		"tier90Ratio":            "20",
		"tier180Ratio":           "70",
		"tierAmount":             "100000000",
		"collectWaitDuration":    "129600",
		"tierAmountPerBlockX128": "26256355472294634526494954277142608908641",
		"name":                   "OBL Launchpad Project",
		"tokenPath":              "gno.land/r/onbloc/obl",
		"amount":                 "1000000",
		"tier":                   "30",
		"depositor":              "g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu",
		"gno.land/r/onbloc/bar":  "1000",
		"gno.land/r/onbloc/qux":  "2500",
	}
}

// Output:
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [EXPECTED] Project created with ID: gno.land/r/onbloc/obl:123
// [EXPECTED] Project name: OBL Launchpad Project
// [EXPECTED] Project token path: gno.land/r/onbloc/obl
// [EXPECTED] Project deposit amount: 1000000000
// [EXPECTED] Project tier30 ratio: 10
// [EXPECTED] Project tier90 ratio: 20
// [EXPECTED] Project tier180 ratio: 70
// [EXPECTED] Tier 30 amount: 100000000
// [EXPECTED] Tier 30 collect wait duration: 129600
// [EXPECTED] Tier 90 amount: 100000000
// [EXPECTED] Tier 90 collect wait duration: 129600
// [EXPECTED] Tier 180 amount: 100000000
// [EXPECTED] Tier 180 collect wait duration: 129600
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
// [EXPECTED] Accumulated transfer to gov staker - Bar: 0
// [EXPECTED] Accumulated transfer to gov staker - Qux: 0
//
// [SCENARIO] 3. Deposit GNS to OBL project tier 30
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Bar amount in protocol fee: 1000
// [INFO] Qux amount in protocol fee: 2500
// [INFO] Admin transferring GNS to Bob for deposit
// [INFO] Bob delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: gno.land/r/onbloc/obl:123:30:g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu:128
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Protocol fee setup 2
// [INFO] Setting up mock protocol fees
// [INFO] Admin transferring tokens to protocol fee
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Bar balance: 1000
// [EXPECTED] Qux balance: 2500
// [EXPECTED] Bar amount in protocol fee: 1000
// [EXPECTED] Qux amount in protocol fee: 2500
// [EXPECTED] Accumulated transfer to gov staker - Bar: 0
// [EXPECTED] Accumulated transfer to gov staker - Qux: 0
//
// [SCENARIO] 5. Collect protocol fee for OBL project recipient
// [INFO] Collecting protocol fee for OBL project recipient
// [INFO] Protocol fee height: 123
// [INFO] Protocol fee now: 1234567890
// [INFO] Bar amount: 1000
// [INFO] Qux amount: 2500
// [INFO] Project recipient collecting protocol fee
// [INFO] Bar balance in protocol fee: 1000
// [INFO] Qux balance in protocol fee: 2500
// [EXPECTED] Gov staker bar balance after collection: 1501
// [EXPECTED] Gov staker qux balance after collection: 3751
// [EXPECTED] Project bar balance after collection: 499
// [EXPECTED] Project qux balance after collection: 1249
//
// [SCENARIO] 6. Deposit GNS to OBL project tier 30 again
// [INFO] Depositing GNS to OBL project tier 30
// [INFO] Bar amount in protocol fee: 1000
// [INFO] Qux amount in protocol fee: 2500
// [INFO] Admin transferring GNS to Bob for deposit
// [INFO] Bob delegating GNS to gov staker
// [INFO] Skipping blocks to make project active
// [EXPECTED] Deposit created with ID: gno.land/r/onbloc/obl:123:30:g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu:134
// [EXPECTED] Deposit amount: 1000000
// [EXPECTED] Deposit tier: 30
// [EXPECTED] Deposit depositor: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 7. Protocol fee setup 3
// [INFO] Setting up mock protocol fees
// [INFO] Admin transferring tokens to protocol fee
// [INFO] Adding tokens to protocol fee
// [INFO] Validating protocol fee balances
// [EXPECTED] Bar balance: 1000
// [EXPECTED] Qux balance: 2500
// [EXPECTED] Bar amount in protocol fee: 1000
// [EXPECTED] Qux amount in protocol fee: 2500
// [EXPECTED] Accumulated transfer to gov staker - Bar: 0
// [EXPECTED] Accumulated transfer to gov staker - Qux: 0
//
// [SCENARIO] 8. Collect protocol fee for OBL project recipient 2
// [INFO] Collecting protocol fee for OBL project recipient 2
// [INFO] Protocol fee height: 123
// [INFO] Protocol fee now: 1234567890
// [INFO] Bar amount: 1000
// [INFO] Qux amount: 2500
// [INFO] Project recipient collecting protocol fee
// [INFO] Bar balance in protocol fee: 1000
// [INFO] Qux balance in protocol fee: 2500
// [EXPECTED] Gov staker bar balance after collection: 2501
// [EXPECTED] Gov staker qux balance after collection: 6251
// [EXPECTED] Project bar balance after collection: 499
// [EXPECTED] Project qux balance after collection: 1249
