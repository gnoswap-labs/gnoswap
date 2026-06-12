// PKGPATH: gno.land/r/gnoswap/v1/main

// Gov/Governance contract upgrade to v2_valid scenario test.
//
// Upgrades governance to an implementation that is identical to v1 (v2_valid
// is a symlinked copy of the v1 sources under a v2_valid module path). The
// purpose is to prove that EVERY state-mutating governance entry point can be
// driven through the upgraded v2_valid implementation without triggering a
// readonly-taint panic, because all writes are routed through the domain
// (proxy) realm that owns the shared storage.
//
// All mutating entry points (from proxy.gno) are exercised AFTER the upgrade:
//   - Vote                       (RMW the v1-created proposal's tally / votes)
//   - Execute                    (RMW proposal action status -> executed)
//   - ProposeText                (insert into proposals BPTree + snapshot)
//   - Cancel                     (RMW proposal action status -> canceled)
//   - ProposeParameterChange     (insert into proposals BPTree + snapshot)
//   - ProposeCommunityPoolSpend  (insert into proposals BPTree + snapshot)
//   - Vote (on a NEW proposal)   (RMW a post-upgrade-created proposal)
//   - Reconfigure                (RMW the governance config BPTree)
//
// Each mutation is followed by reading getters to confirm the write landed.
//
// Flow:
//  1. Initialize governance with v1 and set up voting power (delegate gns).
//  2. v1: create a parameter-change proposal (inserts into proposals BPTree
//     and allocates a proposal struct with a voting-weight snapshot).
//  3. Read the v1-created proposal data via getters.
//  4. Upgrade to v2_valid (blank import + governance UpgradeImpl).
//  5. v2_valid: MUTATE the v1-created proposal by calling Vote, then advance
//     time and Execute it. Taint would panic here if writes were not routed
//     through the domain realm.
//  6. v2_valid: create / cancel / vote-on brand-new proposals of every type,
//     proving the proposals BPTree insert + per-proposal snapshot works after
//     the upgrade.
//  7. v2_valid: Reconfigure the governance config (RMW the config BPTree).
package main

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"

	govStaker "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	govGovernance "gno.land/r/gnoswap/gov/governance"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/governance/v2_valid"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	_ "gno.land/r/gnoswap/rbac"
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	adminRealm    = testing.NewUserRealm(adminAddr)

	currentBlockTime = int64(2)

	// gns token path is registered, so it is a valid community-pool-spend token.
	gnsPath = "gno.land/r/gnoswap/gns"
)

const (
	govGovernanceV1Path      = "gno.land/r/gnoswap/gov/governance/v1"
	govGovernanceV2ValidPath = "gno.land/r/gnoswap/gov/governance/v2_valid"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize gov/governance contract with v1")
	initializeV1(cur)
	println()

	println("[SCENARIO] 2. Set up voting power (delegate gns to admin)")
	setupVotingPower(cur)
	println()

	println("[SCENARIO] 3. v1: create a parameter-change proposal")
	proposalID := createProposalV1(cur)
	println()

	println("[SCENARIO] 4. Read v1-created proposal data")
	readProposal(proposalID)
	println()

	println("[SCENARIO] 5. Upgrade gov/governance contract to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 6. v2_valid: mutate the v1-created proposal (Vote)")
	mutateProposalV2Valid(cur, proposalID)
	println()

	println("[SCENARIO] 7. Read proposal data after Vote (mutated through v2_valid)")
	readProposal(proposalID)
	println()

	println("[SCENARIO] 8. v2_valid: Execute the v1-created proposal (passed quorum)")
	executeProposalV2Valid(cur, proposalID)
	println()

	println("[SCENARIO] 9. v2_valid: ProposeText then Cancel it")
	textID := proposeTextV2Valid(cur)
	cancelProposalV2Valid(cur, textID)
	println()

	println("[SCENARIO] 10. v2_valid: ProposeParameterChange then Cancel it")
	paramID := proposeParameterChangeV2Valid(cur)
	cancelProposalV2Valid(cur, paramID)
	println()

	println("[SCENARIO] 11. v2_valid: ProposeCommunityPoolSpend then Vote on it")
	spendID := proposeCommunityPoolSpendV2Valid(cur)
	voteOnNewProposalV2Valid(cur, spendID)
	println()

	println("[SCENARIO] 12. v2_valid: Reconfigure the governance config")
	reconfigureV2Valid(cur)
	println()
}

func initializeV1(cur realm) {
	currentVersion := govGovernance.GetImplementationPackagePath()
	if currentVersion != govGovernanceV1Path {
		testing.SetRealm(adminRealm)
		govGovernance.UpgradeImpl(cross(cur), govGovernanceV1Path)
		currentVersion = govGovernance.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Gov/Governance initialized with v1: %s\n", currentVersion)
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func setupVotingPower(cur realm) {
	delegatedAmount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	govStaker.Delegate(cross(cur), adminAddr, delegatedAmount, "")

	// Skip the voting weight smoothing duration so the proposal can snapshot
	// a non-zero voting weight at creation time.
	config := govGovernance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)

	ufmt.Printf("[EXPECTED] gns delegated to admin (amount: %d)\n", delegatedAmount)
	println("[INFO] current height:", runtime.ChainHeight())
}

func createProposalV1(cur realm) int64 {
	testing.SetRealm(adminRealm)
	proposalID := govGovernance.ProposeParameterChange(
		cross(cur),
		"emission",
		"change distribution pct",
		1,
		"gno.land/r/gnoswap/emission*EXE*ChangeDistributionPct*EXE*7000,1500,1000,500",
	)

	ufmt.Printf("[EXPECTED] v1 created proposal ID: %d\n", proposalID)

	// Skip the voting start delay so the proposal becomes votable.
	config := govGovernance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())

	return proposalID
}

func readProposal(proposalID int64) {
	pType, _ := govGovernance.GetProposalTypeByProposalId(proposalID)
	status, _ := govGovernance.GetProposalStatusByProposalId(proposalID)
	yea, _ := govGovernance.GetYeaByProposalId(proposalID)
	nay, _ := govGovernance.GetNayByProposalId(proposalID)

	ufmt.Printf("[EXPECTED] proposal %d type: %s\n", proposalID, pType.String())
	ufmt.Printf("[EXPECTED] proposal %d status: %s\n", proposalID, status)
	ufmt.Printf("[EXPECTED] proposal %d yea: %d, nay: %d\n", proposalID, yea, nay)
}

func upgradeToV2Valid(cur realm) {
	currentVersion := govGovernance.GetImplementationPackagePath()
	if currentVersion != govGovernanceV1Path {
		panic(ufmt.Sprintf("Expected v1 before upgrade, got %s", currentVersion))
	}

	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross(cur), govGovernanceV2ValidPath)

	currentVersion = govGovernance.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Gov/Governance upgraded to: %s\n", currentVersion)
	if currentVersion != govGovernanceV2ValidPath {
		panic(ufmt.Sprintf("Expected v2_valid, got %s", currentVersion))
	}
}

// mutateProposalV2Valid votes on the v1-created proposal through the v2_valid
// implementation. Vote performs a read-modify-write on the v1-allocated
// proposal struct (vote tally) and votes map. If the upgraded implementation
// touched the shared storage directly instead of through the domain realm,
// this would abort with a readonly-taint panic.
func mutateProposalV2Valid(cur realm, proposalID int64) {
	testing.SetRealm(adminRealm)
	govGovernance.Vote(cross(cur), proposalID, true)
	ufmt.Printf("[EXPECTED] voted YES on v1-created proposal %d via v2_valid (no taint panic)\n", proposalID)
}

// executeProposalV2Valid advances past the voting period and execution delay so
// the (passed) proposal becomes executable, then Executes it through v2_valid.
// Quorum is reached because the admin's ~1B YES vote exceeds the 50% quorum of
// the ~1B total delegated weight, and yes > no. Execute RMWs the proposal's
// action status (sets executed=true). A direct-storage write under the upgraded
// realm would abort with a readonly-taint panic here.
func executeProposalV2Valid(cur realm, proposalID int64) {
	config := govGovernance.GetLatestConfig()

	// Advance past votingPeriod + executionDelay (relative to the already-passed
	// voting start) so the proposal reaches the StatusExecutable window.
	skip := (int64(config.VotingPeriod) + int64(config.ExecutionDelay)) / currentBlockTime
	testing.SkipHeights(skip)
	println("[INFO] current height:", runtime.ChainHeight())

	statusBefore, _ := govGovernance.GetProposalStatusByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] proposal %d status before execute: %s\n", proposalID, statusBefore)

	testing.SetRealm(adminRealm)
	executedID := govGovernance.Execute(cross(cur), proposalID)
	ufmt.Printf("[EXPECTED] executed proposal ID: %d via v2_valid (no taint panic)\n", executedID)

	statusAfter, _ := govGovernance.GetProposalStatusByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] proposal %d status after execute: %s\n", proposalID, statusAfter)
}

// proposeTextV2Valid creates a brand-new text proposal under v2_valid. This
// inserts a freshly-allocated proposal struct into the proposals BPTree and
// allocates a voting-weight snapshot, all through the upgraded realm.
func proposeTextV2Valid(cur realm) int64 {
	testing.SetRealm(adminRealm)
	id := govGovernance.ProposeText(
		cross(cur),
		"text proposal via v2_valid",
		"signal-only proposal created after upgrade",
	)
	ufmt.Printf("[EXPECTED] v2_valid created text proposal ID: %d (no taint panic)\n", id)
	readProposal(id)
	return id
}

// proposeParameterChangeV2Valid creates a brand-new parameter-change proposal
// under v2_valid.
func proposeParameterChangeV2Valid(cur realm) int64 {
	testing.SetRealm(adminRealm)
	id := govGovernance.ProposeParameterChange(
		cross(cur),
		"param change via v2_valid",
		"change distribution pct after upgrade",
		1,
		"gno.land/r/gnoswap/emission*EXE*ChangeDistributionPct*EXE*7000,1500,1000,500",
	)
	ufmt.Printf("[EXPECTED] v2_valid created parameter-change proposal ID: %d (no taint panic)\n", id)
	readProposal(id)
	return id
}

// proposeCommunityPoolSpendV2Valid creates a brand-new community-pool-spend
// proposal under v2_valid. Only creation + voting are exercised; execution is
// intentionally skipped (see report) because it would require funding the
// community pool.
func proposeCommunityPoolSpendV2Valid(cur realm) int64 {
	testing.SetRealm(adminRealm)
	id := govGovernance.ProposeCommunityPoolSpend(
		cross(cur),
		"community pool spend via v2_valid",
		"spend proposal created after upgrade",
		adminAddr,
		gnsPath,
		int64(1_000),
	)
	ufmt.Printf("[EXPECTED] v2_valid created community-pool-spend proposal ID: %d (no taint panic)\n", id)
	readProposal(id)
	return id
}

// cancelProposalV2Valid cancels a still-upcoming proposal through v2_valid.
// Cancel is only permitted while the proposal is in StatusUpcoming (before the
// voting start delay elapses), so it must be called immediately after creation.
// Cancel RMWs the proposal's action status (sets canceled=true).
func cancelProposalV2Valid(cur realm, proposalID int64) {
	testing.SetRealm(adminRealm)
	canceledID := govGovernance.Cancel(cross(cur), proposalID)
	ufmt.Printf("[EXPECTED] canceled proposal ID: %d via v2_valid (no taint panic)\n", canceledID)

	status, _ := govGovernance.GetProposalStatusByProposalId(proposalID)
	ufmt.Printf("[EXPECTED] proposal %d status after cancel: %s\n", proposalID, status)
}

// voteOnNewProposalV2Valid advances past the voting start delay so the freshly
// created proposal becomes active, then votes YES on it through v2_valid. This
// proves the per-proposal vote tally / votes map allocated AFTER the upgrade is
// also writable through the domain realm.
func voteOnNewProposalV2Valid(cur realm, proposalID int64) {
	config := govGovernance.GetLatestConfig()
	testing.SkipHeights(int64(config.VotingStartDelay) / currentBlockTime)
	println("[INFO] current height:", runtime.ChainHeight())

	testing.SetRealm(adminRealm)
	govGovernance.Vote(cross(cur), proposalID, true)
	ufmt.Printf("[EXPECTED] voted YES on v2_valid-created proposal %d (no taint panic)\n", proposalID)
	readProposal(proposalID)
}

// reconfigureV2Valid updates the governance configuration through v2_valid.
// Reconfigure RMWs the config BPTree (inserts a new config version). It is
// admin/governance gated and is called by the admin realm. The values mirror
// the defaults except for a bumped voting period, so the new config is valid.
func reconfigureV2Valid(cur realm) {
	prevVersion := govGovernance.GetLatestConfigVersion()

	testing.SetRealm(adminRealm)
	newVersion := govGovernance.Reconfigure(
		cross(cur),
		int64(86400),         // votingStartDelay (1 day)
		int64(700000),        // votingPeriod (bumped from default)
		int64(86400),         // votingWeightSmoothingDuration (1 day)
		int64(50),            // quorum (50%)
		int64(1_000_000_000), // proposalCreationThreshold
		int64(86400),         // executionDelay (1 day)
		int64(2592000),       // executionWindow (30 days)
	)
	ufmt.Printf("[EXPECTED] reconfigured: prev version %d -> new version %d (no taint panic)\n", prevVersion, newVersion)

	cfg := govGovernance.GetLatestConfig()
	ufmt.Printf("[EXPECTED] latest config version: %d\n", govGovernance.GetLatestConfigVersion())
	ufmt.Printf("[EXPECTED] latest config votingPeriod: %d\n", cfg.VotingPeriod)
}

// Output:
// [SCENARIO] 1. Initialize gov/governance contract with v1
// [EXPECTED] Gov/Governance initialized with v1: gno.land/r/gnoswap/gov/governance/v1
//
// [SCENARIO] 2. Set up voting power (delegate gns to admin)
// [EXPECTED] gns delegated to admin (amount: 1000000000)
// [INFO] current height: 43323
//
// [SCENARIO] 3. v1: create a parameter-change proposal
// [EXPECTED] v1 created proposal ID: 1
// [INFO] current height: 86523
//
// [SCENARIO] 4. Read v1-created proposal data
// [EXPECTED] proposal 1 type: ParameterChange
// [EXPECTED] proposal 1 status: active
// [EXPECTED] proposal 1 yea: 0, nay: 0
//
// [SCENARIO] 5. Upgrade gov/governance contract to v2_valid
// [EXPECTED] Gov/Governance upgraded to: gno.land/r/gnoswap/gov/governance/v2_valid
//
// [SCENARIO] 6. v2_valid: mutate the v1-created proposal (Vote)
// [EXPECTED] voted YES on v1-created proposal 1 via v2_valid (no taint panic)
//
// [SCENARIO] 7. Read proposal data after Vote (mutated through v2_valid)
// [EXPECTED] proposal 1 type: ParameterChange
// [EXPECTED] proposal 1 status: active
// [EXPECTED] proposal 1 yea: 1000000000, nay: 0
//
// [SCENARIO] 8. v2_valid: Execute the v1-created proposal (passed quorum)
// [INFO] current height: 432123
// [EXPECTED] proposal 1 status before execute: executable
// [EXPECTED] executed proposal ID: 1 via v2_valid (no taint panic)
// [EXPECTED] proposal 1 status after execute: executed
//
// [SCENARIO] 9. v2_valid: ProposeText then Cancel it
// [EXPECTED] v2_valid created text proposal ID: 2 (no taint panic)
// [EXPECTED] proposal 2 type: Text
// [EXPECTED] proposal 2 status: upcoming
// [EXPECTED] proposal 2 yea: 0, nay: 0
// [EXPECTED] canceled proposal ID: 2 via v2_valid (no taint panic)
// [EXPECTED] proposal 2 status after cancel: canceled
//
// [SCENARIO] 10. v2_valid: ProposeParameterChange then Cancel it
// [EXPECTED] v2_valid created parameter-change proposal ID: 3 (no taint panic)
// [EXPECTED] proposal 3 type: ParameterChange
// [EXPECTED] proposal 3 status: upcoming
// [EXPECTED] proposal 3 yea: 0, nay: 0
// [EXPECTED] canceled proposal ID: 3 via v2_valid (no taint panic)
// [EXPECTED] proposal 3 status after cancel: canceled
//
// [SCENARIO] 11. v2_valid: ProposeCommunityPoolSpend then Vote on it
// [EXPECTED] v2_valid created community-pool-spend proposal ID: 4 (no taint panic)
// [EXPECTED] proposal 4 type: CommunityPoolSpend
// [EXPECTED] proposal 4 status: upcoming
// [EXPECTED] proposal 4 yea: 0, nay: 0
// [INFO] current height: 475323
// [EXPECTED] voted YES on v2_valid-created proposal 4 (no taint panic)
// [EXPECTED] proposal 4 type: CommunityPoolSpend
// [EXPECTED] proposal 4 status: active
// [EXPECTED] proposal 4 yea: 1000000000, nay: 0
//
// [SCENARIO] 12. v2_valid: Reconfigure the governance config
// [EXPECTED] reconfigured: prev version 1 -> new version 2 (no taint panic)
// [EXPECTED] latest config version: 2
// [EXPECTED] latest config votingPeriod: 700000
//
