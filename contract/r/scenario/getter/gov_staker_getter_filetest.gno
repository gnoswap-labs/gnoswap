// gov/staker getter test

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")

	delegatorAddr  = testutils.TestAddress("delegator1")
	delegatorRealm = testing.NewUserRealm(delegatorAddr)

	delegateeAddr  = testutils.TestAddress("delegatee1")
	delegateeRealm = testing.NewUserRealm(delegateeAddr)
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Setup test data")
	delegationId1 := setupTestData()
	println()

	println("[SCENARIO] 2. Test Gov Staker Getters")
	testGovStakerGetters(delegationId1)
	println()
}

func setupTestData() int64 {
	println("[INFO] Setting up test data")

	// Transfer GNS to delegator
	println("[INFO] Admin transferring GNS to delegator")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, delegatorAddr, 1_000_000_000)

	// Delegate
	println("[INFO] Delegator delegating to delegatee")
	testing.SetRealm(delegatorRealm)
	gns.Approve(cross, stakerAddr, 1_000_000_000)
	staker.Delegate(cross, delegateeAddr, 500_000_000, "")

	// Skip some height for better testing
	testing.SkipHeights(100)

	// Get the delegation ID from GetDelegationIDs
	testing.SetRealm(stakerRealm)
	delegationIds := staker.GetDelegationIDs(0, 10)
	if len(delegationIds) == 0 {
		panic("no delegations found")
	}
	delegationId := delegationIds[0]

	println("[EXPECTED] Delegation created with ID:", delegationId)

	return delegationId
}

func testGovStakerGetters(delegationId1 int64) {
	println("[INFO] Testing gov staker getters")

	// Set realm to staker for getter calls
	testing.SetRealm(stakerRealm)

	// GetTotalxGnsSupply
	totalxGnsSupply := staker.GetTotalxGnsSupply()
	println("[EXPECTED] Total xGNS Supply:", totalxGnsSupply)

	// GetTotalVoteWeight
	totalVoteWeight := staker.GetTotalVoteWeight()
	println("[EXPECTED] Total Vote Weight:", totalVoteWeight)

	// GetTotalDelegated
	totalDelegated := staker.GetTotalDelegated()
	println("[EXPECTED] Total Delegated:", totalDelegated)

	// GetTotalLockedAmount
	totalLockedAmount := staker.GetTotalLockedAmount()
	println("[EXPECTED] Total Locked Amount:", totalLockedAmount)

	// GetLockedAmount
	lockedAmount := staker.GetLockedAmount()
	println("[EXPECTED] Locked Amount:", lockedAmount)

	// GetUnDelegationLockupPeriod
	lockupPeriod := staker.GetUnDelegationLockupPeriod()
	println("[EXPECTED] Undelegation Lockup Period:", lockupPeriod)

	// GetEmissionRewardBalance
	emissionRewardBalance := staker.GetEmissionRewardBalance()
	println("[EXPECTED] Emission Reward Balance:", emissionRewardBalance)

	println()

	// GetDelegationCount
	delegationCount := staker.GetDelegationCount()
	println("[EXPECTED] Delegation Count:", delegationCount)

	// GetDelegationIDs
	delegationIds := staker.GetDelegationIDs(0, 10)
	println("[EXPECTED] Delegation IDs (offset=0, limit=10):", len(delegationIds), "delegations")
	for i, id := range delegationIds {
		ufmt.Printf("[EXPECTED] - Delegation %d: %d\n", i+1, id)
	}

	println()

	// ExistsDelegation
	exists := staker.ExistsDelegation(delegationId1)
	println("[EXPECTED] Delegation", delegationId1, "exists:", exists)

	// GetDelegation
	delegation, err := staker.GetDelegation(delegationId1)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Delegation details:")
	println("[EXPECTED] - ID:", delegation.ID())
	println("[EXPECTED] - Delegator:", delegation.DelegateFrom())
	println("[EXPECTED] - Delegatee:", delegation.DelegateTo())
	println("[EXPECTED] - Total Delegated Amount:", delegation.TotalDelegatedAmount())
	println("[EXPECTED] - Collected Amount:", delegation.CollectedAmount())

	println()

	// GetDelegatorDelegationCount
	delegatorDelegationCount := staker.GetDelegatorDelegationCount(delegatorAddr)
	println("[EXPECTED] Delegator Delegation Count:", delegatorDelegationCount)

	// GetDelegatorDelegationIDs
	delegatorDelegationIds := staker.GetDelegatorDelegationIDs(delegatorAddr, 0, 10)
	println("[EXPECTED] Delegator Delegation IDs (offset=0, limit=10):", len(delegatorDelegationIds), "delegations")
	for i, id := range delegatorDelegationIds {
		ufmt.Printf("[EXPECTED] - Delegator Delegation %d: %d\n", i+1, id)
	}

	println()

	// HasDelegationSnapshotsKey
	hasSnapshots := staker.HasDelegationSnapshotsKey()
	println("[EXPECTED] Has Delegation Snapshots Key:", hasSnapshots)

	// GetTotalDelegationAmountAtSnapshot
	// Using height 0 as snapshot time since no previous snapshots exist
	snapshotAmount, snapshotExists := staker.GetTotalDelegationAmountAtSnapshot(0)
	println("[EXPECTED] Total Delegation Amount At Snapshot:", snapshotAmount, "exists:", snapshotExists)

	// GetUserDelegationAmountAtSnapshot
	userSnapshotAmount, userSnapshotExists := staker.GetUserDelegationAmountAtSnapshot(delegatorAddr, 0)
	println("[EXPECTED] User Delegation Amount At Snapshot:", userSnapshotAmount, "exists:", userSnapshotExists)

	println()

	// GetDelegationWithdrawCount
	withdrawCount := staker.GetDelegationWithdrawCount(delegationId1)
	println("[EXPECTED] Delegation Withdraw Count:", withdrawCount)

	// GetDelegationWithdraws
	withdraws, err := staker.GetDelegationWithdraws(delegationId1, 0, 10)
	if err != nil {
		panic(err)
	}
	println("[EXPECTED] Delegation Withdraws (offset=0, limit=10):", len(withdraws), "withdraws")
	for i, withdraw := range withdraws {
		ufmt.Printf("[EXPECTED] - Withdraw %d: UnDelegateAmount=%d, CollectedAmount=%d\n",
			i+1, withdraw.UnDelegateAmount(), withdraw.CollectedAmount())
	}

	// GetCollectableWithdrawAmount
	collectableAmount := staker.GetCollectableWithdrawAmount(delegationId1)
	println("[EXPECTED] Collectable Withdraw Amount:", collectableAmount)

	println()

	// GetProtocolFeeAccumulatedX128PerStake
	protocolFeeAccumulated := staker.GetProtocolFeeAccumulatedX128PerStake("gno.land/r/gnoswap/pool:v1")
	println("[EXPECTED] Protocol Fee Accumulated X128 Per Stake:", protocolFeeAccumulated.ToString())

	// GetProtocolFeeAmounts
	protocolFeeAmount := staker.GetProtocolFeeAmount("gno.land/r/gnoswap/pool:v1")
	println("[EXPECTED] Protocol Fee Amounts:", protocolFeeAmount)

	// GetProtocolFeeAccumulatedTimestamp
	protocolFeeAccumulatedTime := staker.GetProtocolFeeAccumulatedTimestamp()
	println("[EXPECTED] Protocol Fee Accumulated Timestamp:", protocolFeeAccumulatedTime)

	println()

	// GetEmissionAccumulatedX128PerStake
	emissionAccumulated := staker.GetEmissionAccumulatedX128PerStake()
	println("[EXPECTED] Emission Accumulated X128 Per Stake:", emissionAccumulated.ToString())

	// GetEmissionDistributedAmount
	emissionDistributed := staker.GetEmissionDistributedAmount()
	println("[EXPECTED] Emission Distributed Amount:", emissionDistributed)

	// GetEmissionAccumulatedTimestamp
	emissionAccumulatedTime := staker.GetEmissionAccumulatedTimestamp()
	println("[EXPECTED] Emission Accumulated Timestamp:", emissionAccumulatedTime)

	println()

	// GetClaimableRewardByAddress
	emissionReward, protocolFeeRewards, err := staker.GetClaimableRewardByAddress(delegatorAddr)
	println("[EXPECTED] Claimable Reward By Address:")
	println("[EXPECTED] - Emission Reward:", emissionReward)
	println("[EXPECTED] - Protocol Fee Rewards:")
	for tokenPath, reward := range protocolFeeRewards {
		ufmt.Printf("[EXPECTED]   - %s: %d\n", tokenPath, reward)
	}

	println()

	// GetClaimableRewardByLaunchpad
	launchpadEmissionReward, launchpadProtocolFeeRewards, err := staker.GetClaimableRewardByLaunchpad(delegatorAddr)
	println("[EXPECTED] Claimable Reward By Launchpad:")
	println("[EXPECTED] - Emission Reward:", launchpadEmissionReward)
	println("[EXPECTED] - Protocol Fee Rewards:")
	for tokenPath, reward := range launchpadProtocolFeeRewards {
		ufmt.Printf("[EXPECTED]   - %s: %d\n", tokenPath, reward)
	}

	println()

	// GetClaimableRewardByRewardID
	rewardIdEmissionReward, rewardIdProtocolFeeRewards, err := staker.GetClaimableRewardByRewardID("test-reward-id")
	println("[EXPECTED] Claimable Reward By RewardID:")
	println("[EXPECTED] - Emission Reward:", rewardIdEmissionReward)
	println("[EXPECTED] - Protocol Fee Rewards:")
	for tokenPath, reward := range rewardIdProtocolFeeRewards {
		ufmt.Printf("[EXPECTED]   - %s: %d\n", tokenPath, reward)
	}

	println()

	// GetLaunchpadProjectDeposit
	launchpadDeposit, launchpadDepositExists := staker.GetLaunchpadProjectDeposit("g1wpex76n9vd6rzh6lta047h6lta047h6lztprp7")
	println("[EXPECTED] Launchpad Project Deposit:", launchpadDeposit, "exists:", launchpadDepositExists)
}

// Output:
// [SCENARIO] 1. Setup test data
// [INFO] Setting up test data
// [INFO] Admin transferring GNS to delegator
// [INFO] Delegator delegating to delegatee
// [EXPECTED] Delegation created with ID: 1
//
// [SCENARIO] 2. Test Gov Staker Getters
// [INFO] Testing gov staker getters
// [EXPECTED] Total xGNS Supply: 500000000
// [EXPECTED] Total Vote Weight: 500000000
// [EXPECTED] Total Delegated: 500000000
// [EXPECTED] Total Locked Amount: 500000000
// [EXPECTED] Locked Amount: 500000000
// [EXPECTED] Undelegation Lockup Period: 604800
// [EXPECTED] Emission Reward Balance: 0
//
// [EXPECTED] Delegation Count: 1
// [EXPECTED] Delegation IDs (offset=0, limit=10): 1 delegations
// [EXPECTED] - Delegation 1: 1
//
// [EXPECTED] Delegation 1 exists: true
// [EXPECTED] Delegation details:
// [EXPECTED] - ID: 1
// [EXPECTED] - Delegator: g1v3jkcet8v96x7u33ta047h6lta047h6ldk5j9l
// [EXPECTED] - Delegatee: g1v3jkcet8v96x2ef3ta047h6lta047h6lcpu3dr
// [EXPECTED] - Total Delegated Amount: 500000000
// [EXPECTED] - Collected Amount: 0
//
// [EXPECTED] Delegator Delegation Count: 1
// [EXPECTED] Delegator Delegation IDs (offset=0, limit=10): 1 delegations
// [EXPECTED] - Delegator Delegation 1: 1
//
// [EXPECTED] Has Delegation Snapshots Key: true
// [EXPECTED] Total Delegation Amount At Snapshot: 0 exists: false
// [EXPECTED] User Delegation Amount At Snapshot: 0 exists: false
//
// [EXPECTED] Delegation Withdraw Count: 0
// [EXPECTED] Delegation Withdraws (offset=0, limit=10): 0 withdraws
// [EXPECTED] Collectable Withdraw Amount: 0
//
// [EXPECTED] Protocol Fee Accumulated X128 Per Stake: 0
// [EXPECTED] Protocol Fee Amounts: 0
// [EXPECTED] Protocol Fee Accumulated Timestamp: 1234567890
//
// [EXPECTED] Emission Accumulated X128 Per Stake: 0
// [EXPECTED] Emission Distributed Amount: 0
// [EXPECTED] Emission Accumulated Timestamp: 0
//
// [EXPECTED] Claimable Reward By Address:
// [EXPECTED] - Emission Reward: 0
// [EXPECTED] - Protocol Fee Rewards:
//
// [EXPECTED] Claimable Reward By Launchpad:
// [EXPECTED] - Emission Reward: 0
// [EXPECTED] - Protocol Fee Rewards:
//
// [EXPECTED] Claimable Reward By RewardID:
// [EXPECTED] - Emission Reward: 0
// [EXPECTED] - Protocol Fee Rewards:
//
// [EXPECTED] Launchpad Project Deposit: 0 exists: false
