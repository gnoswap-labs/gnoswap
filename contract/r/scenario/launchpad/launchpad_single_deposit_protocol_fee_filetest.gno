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
	println("[SCENARIO] 1. Create ETH launchpad project")
	createETHProject()
	projectTier30Id := "gno.land/r/gnoswap/test_token/eth:123:30"
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

func createETHProject() {
	println("[INFO] Creating ETH launchpad project")

	recipientAddr := projectAddr
	projectName := "ETH Launchpad Project"
	rewardTokenPath := "gno.land/r/gnoswap/test_token/eth"
	rewardAmount := int64(1_000_000_000)
	conditionPath := ""
	conditionsAmount := ""
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

func simulateSwapFee(atomAmount, solAmount int64) {
	println("[INFO] Simulating swap fee from router")

	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)

	ufmt.Printf("[INFO] Swap fee added - ATOM: %d, SOL: %d\n", atomAmount, solAmount)
	testing.SkipHeights(1)
}

func simulatePoolCreationFee(atomAmount, solAmount int64) {
	println("[INFO] Simulating pool creation fee")

	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)

	ufmt.Printf("[INFO] Pool creation fee added - ATOM: %d, SOL: %d\n", atomAmount, solAmount)
	testing.SkipHeights(1)
}

func simulateWithdrawalFee(atomAmount, solAmount int64) {
	println("[INFO] Simulating withdrawal fee from LP position")

	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)

	ufmt.Printf("[INFO] Withdrawal fee added - ATOM: %d, SOL: %d\n", atomAmount, solAmount)
	testing.SkipHeights(1)
}

func simulateUnstakingFee(atomAmount, solAmount int64) {
	println("[INFO] Simulating unstaking fee from staker rewards")

	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, atomAmount)
	sol.Transfer(cross, stakerAddr, solAmount)

	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, atomAmount)
	sol.Approve(cross, protocolFeeAddr, solAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", atomAmount)
	protocol_fee.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", solAmount)

	ufmt.Printf("[INFO] Unstaking fee added - ATOM: %d, SOL: %d\n", atomAmount, solAmount)
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

	prevAtomBalance := atom.BalanceOf(projectAddr)
	prevSolBalance := sol.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] ATOM balance before: %d\n", prevAtomBalance)
	ufmt.Printf("[INFO] SOL balance before: %d\n", prevSolBalance)

	launchpad.CollectProtocolFee(cross)

	afterAtomBalance := atom.BalanceOf(projectAddr)
	afterSolBalance := sol.BalanceOf(projectAddr)
	ufmt.Printf("[INFO] ATOM balance after: %d\n", afterAtomBalance)
	ufmt.Printf("[INFO] SOL balance after: %d\n", afterSolBalance)
	ufmt.Printf("[INFO] ATOM collected: %d\n", afterAtomBalance-prevAtomBalance)
	ufmt.Printf("[INFO] SOL collected: %d\n", afterSolBalance-prevSolBalance)
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
// [SCENARIO] 1. Create ETH launchpad project
// [INFO] Creating ETH launchpad project
// [INFO] Admin creating ETH project
// [INFO] Skipping 120960 blocks to activate project
// [INFO] Project created with ID: gno.land/r/gnoswap/test_token/eth:123
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
// [INFO] Swap fee added - ATOM: 500, SOL: 1000
//
// [SCENARIO] 4. Simulate pool creation fee
// [INFO] Pool creation fee is collected when a new pool is created
// [INFO] Simulating pool creation fee
// [INFO] Pool creation fee added - ATOM: 300, SOL: 600
//
// [SCENARIO] 5. Simulate withdrawal fee
// [INFO] Withdrawal fee is collected when LP withdraws liquidity
// [INFO] Simulating withdrawal fee from LP position
// [INFO] Withdrawal fee added - ATOM: 200, SOL: 400
//
// [SCENARIO] 6. Simulate unstaking fee
// [INFO] Unstaking fee is collected when staker collects staking rewards
// [INFO] Simulating unstaking fee from staker rewards
// [INFO] Unstaking fee added - ATOM: 100, SOL: 200
//
// [SCENARIO] 7. Distribute protocol fee
// [INFO] Distributing protocol fee to gov/staker
// [INFO] Protocol fee distributed
//
// [SCENARIO] 8. Project recipient collects protocol fee
// [INFO] Project recipient collecting protocol fee
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/gnoswap/test_token/atom:1099 gno.land/r/gnoswap/test_token/sol:2199]
// [INFO] ATOM balance before: 0
// [INFO] SOL balance before: 0
// [INFO] ATOM balance after: 1099
// [INFO] SOL balance after: 2199
// [INFO] ATOM collected: 1099
// [INFO] SOL collected: 2199
//
// [SCENARIO] 9. Add more protocol fees and collect again
// [INFO] Adding additional swap and unstaking fees
// [INFO] Simulating swap fee from router
// [INFO] Swap fee added - ATOM: 1000, SOL: 2000
// [INFO] Simulating unstaking fee from staker rewards
// [INFO] Unstaking fee added - ATOM: 500, SOL: 1000
// [INFO] Distributing protocol fee to gov/staker
// [INFO] Protocol fee distributed
// [INFO] Project recipient collecting protocol fee
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/gnoswap/test_token/atom:1499 gno.land/r/gnoswap/test_token/sol:2999]
// [INFO] ATOM balance before: 1099
// [INFO] SOL balance before: 2199
// [INFO] ATOM balance after: 2598
// [INFO] SOL balance after: 5198
// [INFO] ATOM collected: 1499
// [INFO] SOL collected: 2999
