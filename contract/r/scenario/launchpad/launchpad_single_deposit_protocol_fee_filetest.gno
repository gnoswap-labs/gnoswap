// launchpad single deposit protocol fee

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

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

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

	launchpadAddr, _   = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	projectAddr  = testutils.TestAddress("project-owner")
	projectRealm = testing.NewUserRealm(projectAddr)
)

func main() {
	println("[SCENARIO] 1. Create OBL launchpad project")
	createOBLProject()
	projectTier30Id := "gno.land/r/onbloc/obl:123:30"
	println()

	println("[SCENARIO] 2. Single deposit by Alice")
	depositGns(aliceAddr, projectTier30Id, int64(1_000_000))
	println()

	println("[SCENARIO] 3. Simulate swap fee")
	println("[INFO] Swap fee is collected when users swap tokens via router")
	simulateSwapFee(500, 1000)
	println()

	println("[SCENARIO] 4. Simulate pool creation fee")
	println("[INFO] Pool creation fee is collected when a new pool is created")
	simulatePoolCreationFee(300, 600)
	println()

	println("[SCENARIO] 5. Simulate withdrawal fee")
	println("[INFO] Withdrawal fee is collected when LP withdraws liquidity")
	simulateWithdrawalFee(200, 400)
	println()

	println("[SCENARIO] 6. Simulate unstaking fee")
	println("[INFO] Unstaking fee is collected when staker collects staking rewards")
	simulateUnstakingFee(100, 200)
	println()

	println("[SCENARIO] 7. Distribute protocol fee")
	distributeProtocolFee()
	println()

	println("[SCENARIO] 8. Project recipient collects protocol fee")
	collectProtocolFeeForProjectRecipient()
	println()

	println("[SCENARIO] 9. Add more protocol fees and collect again")
	println("[INFO] Adding additional swap and unstaking fees")
	simulateSwapFee(1000, 2000)
	simulateUnstakingFee(500, 1000)
	distributeProtocolFee()
	collectProtocolFeeForProjectRecipient()
	println()
}

func createOBLProject() {
	println("[INFO] Creating OBL launchpad project")

	recipientAddr := projectAddr
	projectName := "OBL Launchpad Project"
	rewardTokenPath := "gno.land/r/onbloc/obl"
	rewardAmount := int64(1_000_000_000)
	conditionPath := ""
	conditionsAmount := ""
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
		tier30Ratio,
		tier90Ratio,
		tier180Ratio,
		startTime,
	)

	println("[INFO] Skipping 120960 blocks to activate project")
	testing.SkipHeights(120960)

	println("[INFO] Project created with ID:", projectId)
}

func depositGns(depositorAddr address, projectTierId string, depositAmount int64) {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] Admin transferring GNS to depositor")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, depositorAddr, depositAmount)

	println("[INFO] Depositor approving launchpad to spend GNS")
	testing.SetRealm(testing.NewUserRealm(depositorAddr))
	gns.Approve(cross, launchpadAddr, depositAmount)
	depositId := launchpad.DepositGns(
		cross,
		projectTierId,
		depositAmount,
		"",
	)
	println("[INFO] Deposit created with ID:", depositId)
	ufmt.Printf("[INFO] Deposit amount: %d GNS\n", depositAmount)

	testing.SkipHeights(1)
}

func simulateSwapFee(barAmount, quxAmount int64) {
	println("[INFO] Simulating swap fee from router")

	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, barAmount)
	qux.Transfer(cross, protocolFeeAddr, quxAmount)

	testing.SetRealm(stakerRealm)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", barAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", quxAmount)

	ufmt.Printf("[INFO] Swap fee added - BAR: %d, QUX: %d\n", barAmount, quxAmount)
	testing.SkipHeights(1)
}

func simulatePoolCreationFee(barAmount, quxAmount int64) {
	println("[INFO] Simulating pool creation fee")

	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, barAmount)
	qux.Transfer(cross, protocolFeeAddr, quxAmount)

	testing.SetRealm(stakerRealm)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", barAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", quxAmount)

	ufmt.Printf("[INFO] Pool creation fee added - BAR: %d, QUX: %d\n", barAmount, quxAmount)
	testing.SkipHeights(1)
}

func simulateWithdrawalFee(barAmount, quxAmount int64) {
	println("[INFO] Simulating withdrawal fee from LP position")

	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, barAmount)
	qux.Transfer(cross, protocolFeeAddr, quxAmount)

	testing.SetRealm(stakerRealm)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", barAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", quxAmount)

	ufmt.Printf("[INFO] Withdrawal fee added - BAR: %d, QUX: %d\n", barAmount, quxAmount)
	testing.SkipHeights(1)
}

func simulateUnstakingFee(barAmount, quxAmount int64) {
	println("[INFO] Simulating unstaking fee from staker rewards")

	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, barAmount)
	qux.Transfer(cross, protocolFeeAddr, quxAmount)

	testing.SetRealm(stakerRealm)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", barAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", quxAmount)

	ufmt.Printf("[INFO] Unstaking fee added - BAR: %d, QUX: %d\n", barAmount, quxAmount)
	testing.SkipHeights(1)
}

func distributeProtocolFee() {
	println("[INFO] Distributing protocol fee to gov/staker")

	testing.SetRealm(govStakerRealm)
	protocol_fee.DistributeProtocolFee(cross)

	println("[INFO] Protocol fee distributed")
	testing.SkipHeights(1)
}

func collectProtocolFeeForProjectRecipient() {
	println("[INFO] Project recipient collecting protocol fee")

	testing.SetRealm(govStakerRealm)
	emissionReward, protocolFeeRewards, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(protocolFeeRewards))

	testing.SetRealm(projectRealm)

	prevBarBalance := bar.BalanceOf(projectAddr)
	prevQuxBalance := qux.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] BAR balance before: %d\n", prevBarBalance)
	ufmt.Printf("[INFO] QUX balance before: %d\n", prevQuxBalance)

	launchpad.CollectProtocolFee(cross)

	afterBarBalance := bar.BalanceOf(projectAddr)
	afterQuxBalance := qux.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] BAR balance after: %d\n", afterBarBalance)
	ufmt.Printf("[INFO] QUX balance after: %d\n", afterQuxBalance)
	ufmt.Printf("[INFO] BAR collected: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[INFO] QUX collected: %d\n", afterQuxBalance-prevQuxBalance)
}

func formatProtocolFees(fees map[string]int64) string {
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
// [SCENARIO] 1. Create OBL launchpad project
// [INFO] Creating OBL launchpad project
// [INFO] Admin creating OBL project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/onbloc/obl:123
//
// [SCENARIO] 2. Single deposit by Alice
// [INFO] Admin transferring GNS to depositor
// [INFO] Depositor approving launchpad to spend GNS
// [INFO] Deposit created with ID: 1
// [INFO] Deposit amount: 1000000 GNS
//
// [SCENARIO] 3. Simulate swap fee
// [INFO] Swap fee is collected when users swap tokens via router
// [INFO] Simulating swap fee from router
// [INFO] Swap fee added - BAR: 500, QUX: 1000
//
// [SCENARIO] 4. Simulate pool creation fee
// [INFO] Pool creation fee is collected when a new pool is created
// [INFO] Simulating pool creation fee
// [INFO] Pool creation fee added - BAR: 300, QUX: 600
//
// [SCENARIO] 5. Simulate withdrawal fee
// [INFO] Withdrawal fee is collected when LP withdraws liquidity
// [INFO] Simulating withdrawal fee from LP position
// [INFO] Withdrawal fee added - BAR: 200, QUX: 400
//
// [SCENARIO] 6. Simulate unstaking fee
// [INFO] Unstaking fee is collected when staker collects staking rewards
// [INFO] Simulating unstaking fee from staker rewards
// [INFO] Unstaking fee added - BAR: 100, QUX: 200
//
// [SCENARIO] 7. Distribute protocol fee
// [INFO] Distributing protocol fee to gov/staker
// [INFO] Protocol fee distributed
//
// [SCENARIO] 8. Project recipient collects protocol fee
// [INFO] Project recipient collecting protocol fee
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:1099 gno.land/r/onbloc/qux:2199]
// [INFO] BAR balance before: 0
// [INFO] QUX balance before: 0
// [INFO] BAR balance after: 1099
// [INFO] QUX balance after: 2199
// [INFO] BAR collected: 1099
// [INFO] QUX collected: 2199
//
// [SCENARIO] 9. Add more protocol fees and collect again
// [INFO] Adding additional swap and unstaking fees
// [INFO] Simulating swap fee from router
// [INFO] Swap fee added - BAR: 1000, QUX: 2000
// [INFO] Simulating unstaking fee from staker rewards
// [INFO] Unstaking fee added - BAR: 500, QUX: 1000
// [INFO] Distributing protocol fee to gov/staker
// [INFO] Protocol fee distributed
// [INFO] Project recipient collecting protocol fee
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:1499 gno.land/r/onbloc/qux:2999]
// [INFO] BAR balance before: 1099
// [INFO] QUX balance before: 2199
// [INFO] BAR balance after: 2598
// [INFO] QUX balance after: 5198
// [INFO] BAR collected: 1499
// [INFO] QUX collected: 2999
