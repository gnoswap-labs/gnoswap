// PKGPATH: gno.land/r/gnoswap/v1/main

// Gov/Governance contract upgrade scenario test with data validation.
//
// Proposals, their vote tallies and the config history live in the shared KV
// store. This test creates a canceled proposal and a voted-on parameter-change
// proposal with v1, snapshots what the public getters expose, walks the
// implementation through v2_invalid (which must block the calls) up to
// v3_valid, asserts the snapshot is unchanged, and then finishes the v1-created
// proposal lifecycle (execute + reconfigure) through the new implementation.
package main

import (
	"strconv"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	govGovernance "gno.land/r/gnoswap/gov/governance"
	govStaker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/gov/governance/v1"
	_ "gno.land/r/gnoswap/gov/governance/v2_invalid"
	_ "gno.land/r/gnoswap/gov/governance/v3_valid"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/staker/v1"
)

var t *testing.T

const (
	governanceV1Path        = "gno.land/r/gnoswap/gov/governance/v1"
	governanceV2InvalidPath = "gno.land/r/gnoswap/gov/governance/v2_invalid"
	governanceV3ValidPath   = "gno.land/r/gnoswap/gov/governance/v3_valid"

	blockTimeSeconds = int64(5)

	delegateAmount     = int64(5_000_000_000)
	newUnStakingFee    = uint64(150)
	parameterChangeMsg = "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*150"
)

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	adminRealm = testing.NewUserRealm(adminAddr)

	aliceAddr = testutils.TestAddress("alice")

	textProposalId  int64
	paramProposalId int64

	config govGovernance.Config

	// snapshot of the v1-written state
	v1ProposalCount     int
	v1ProposalIDs       []int64
	v1TextStatus        string
	v1ParamProposer     address
	v1ParamTitle        string
	v1ParamDescription  string
	v1ParamType         string
	v1ParamYea          int64
	v1ParamNay          int64
	v1ParamQuorum       int64
	v1ParamStatus       string
	v1ParamConfigVer    int64
	v1AdminVoteWeight   int64
	v1AdminVotedAt      int64
	v1UserProposalCount int
	v1LatestConfigVer   int64
	v1VotingPeriod      int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize governance contract with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Delegate GNS so the proposal threshold is met")
	delegate(cur)
	println()

	println("[SCENARIO] 3. Create and cancel a text proposal with v1")
	createAndCancelTextProposal(cur)
	println()

	println("[SCENARIO] 4. Create and vote on a parameter change proposal with v1")
	createAndVoteParameterChangeProposal(cur)
	println()

	println("[SCENARIO] 5. Snapshot v1 data through the getters")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 6. Upgrade to v2_invalid")
	upgradeTo(cur, governanceV2InvalidPath)
	println()

	println("[SCENARIO] 7. Mutating calls must be blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(adminRealm)
		govGovernance.ProposeText(cross(cur), "blocked", "blocked")
	}, "[EXPECTED] ProposeText is blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(adminRealm)
		govGovernance.Execute(cross(cur), paramProposalId)
	}, "[EXPECTED] Execute is blocked by v2_invalid")
	println()

	println("[SCENARIO] 8. Upgrade to v3_valid")
	upgradeTo(cur, governanceV3ValidPath)
	println()

	println("[SCENARIO] 9. Validate the v1 proposal data through v3_valid")
	validateSnapshot()
	println()

	println("[SCENARIO] 10. Finish the v1 proposal lifecycle with v3_valid")
	executeAndReconfigure(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross(cur), governanceV1Path)
	var err error
	config, err = govGovernance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	println("[EXPECTED] implementation:", govGovernance.GetImplementationPackagePath())
	println("[EXPECTED] config version:", govGovernance.GetLatestConfigVersion())
	println("[EXPECTED] voting period / quorum / threshold:",
		config.VotingPeriod, config.Quorum, config.ProposalCreationThreshold)
}

func delegate(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), govStakerAddr, delegateAmount)
	govStaker.Delegate(cross(cur), adminAddr, delegateAmount, "")
	testing.SkipHeights(1)

	// the voting weight is averaged over the smoothing duration
	testing.SkipHeights(config.VotingWeightSmoothingDuration / blockTimeSeconds)

	println("[EXPECTED] total delegated:", govStaker.GetTotalDelegated())
	uassert.Equal(t, delegateAmount, govStaker.GetTotalDelegated())
}

func createAndCancelTextProposal(cur realm) {
	testing.SetRealm(adminRealm)
	textProposalId = govGovernance.ProposeText(cross(cur), "text proposal", "signal only")
	testing.SkipHeights(1)

	title, _ := govGovernance.GetTitleByProposalId(textProposalId)
	proposer, _ := govGovernance.GetProposerByProposalId(textProposalId)
	println("[EXPECTED] text proposal id:", textProposalId)
	println("[EXPECTED] text proposal title:", title)
	println("[EXPECTED] text proposal proposer is admin:", proposer == adminAddr)

	// a proposer may only hold one active proposal, so the text proposal is
	// canceled before the parameter change proposal is created
	govGovernance.Cancel(cross(cur), textProposalId)
	testing.SkipHeights(1)

	status, _ := govGovernance.GetProposalStatusByProposalId(textProposalId)
	println("[EXPECTED] text proposal status:", status)
	uassert.Equal(t, "canceled", status)
}

func createAndVoteParameterChangeProposal(cur realm) {
	testing.SetRealm(adminRealm)
	paramProposalId = govGovernance.ProposeParameterChange(
		cross(cur),
		"raise the unstaking fee",
		"routes staker.SetUnStakingFee through governance",
		1,
		parameterChangeMsg,
	)
	testing.SkipHeights(1)

	proposalType, _ := govGovernance.GetProposalTypeByProposalId(paramProposalId)
	println("[EXPECTED] param proposal id:", paramProposalId)
	println("[EXPECTED] param proposal type:", proposalType.String())

	// voting opens after the start delay
	testing.SkipHeights(config.VotingStartDelay / blockTimeSeconds)
	testing.SetRealm(adminRealm)
	govGovernance.Vote(cross(cur), paramProposalId, true)
	testing.SkipHeights(1)

	yea, _ := govGovernance.GetYeaByProposalId(paramProposalId)
	nay, _ := govGovernance.GetNayByProposalId(paramProposalId)
	quorum, maxVotingWeight, yesWeight, noWeight, _ := govGovernance.GetVoteStatus(paramProposalId)
	voteWeight, _ := govGovernance.GetVoteWeight(paramProposalId, adminAddr)

	println("[EXPECTED] yea / nay:", yea, nay)
	println("[EXPECTED] quorum / max / yes / no:", quorum, maxVotingWeight, yesWeight, noWeight)
	println("[EXPECTED] admin vote weight:", voteWeight)
	println("[EXPECTED] voting info count:", govGovernance.GetVotingInfos(paramProposalId).Size())
	println("[EXPECTED] admin has voted:", govGovernance.ExistsVotingInfo(paramProposalId, adminAddr))

	// the whole delegated stake voted yes, so the quorum is met
	uassert.Equal(t, delegateAmount, yea)
	uassert.Equal(t, int64(0), nay)
	uassert.Equal(t, delegateAmount, voteWeight)
	uassert.True(t, yesWeight >= quorum)
}

func captureV1Snapshot() {
	v1ProposalCount = govGovernance.GetProposals().Size()
	v1ProposalIDs = collectProposalIDs(0, 10)
	v1TextStatus, _ = govGovernance.GetProposalStatusByProposalId(textProposalId)
	v1ParamProposer, _ = govGovernance.GetProposerByProposalId(paramProposalId)
	v1ParamTitle, _ = govGovernance.GetTitleByProposalId(paramProposalId)
	v1ParamDescription, _ = govGovernance.GetDescriptionByProposalId(paramProposalId)
	proposalType, _ := govGovernance.GetProposalTypeByProposalId(paramProposalId)
	v1ParamType = proposalType.String()
	v1ParamYea, _ = govGovernance.GetYeaByProposalId(paramProposalId)
	v1ParamNay, _ = govGovernance.GetNayByProposalId(paramProposalId)
	v1ParamQuorum, _ = govGovernance.GetQuorumAmountByProposalId(paramProposalId)
	v1ParamStatus, _ = govGovernance.GetProposalStatusByProposalId(paramProposalId)
	v1ParamConfigVer, _ = govGovernance.GetConfigVersionByProposalId(paramProposalId)
	v1AdminVoteWeight, _ = govGovernance.GetVoteWeight(paramProposalId, adminAddr)
	v1AdminVotedAt, _ = govGovernance.GetVotedAt(paramProposalId, adminAddr)
	v1UserProposalCount = userProposalCount(adminAddr)
	v1LatestConfigVer = govGovernance.GetLatestConfigVersion()
	config, err := govGovernance.GetLatestConfig()
	uassert.NoError(t, err)
	v1VotingPeriod = config.VotingPeriod

	println("[EXPECTED] snapshot proposal count:", v1ProposalCount)
	println("[EXPECTED] snapshot proposal ids:", len(v1ProposalIDs))
	for _, id := range v1ProposalIDs {
		println("[EXPECTED] snapshot proposal id:", id)
	}
	println("[EXPECTED] snapshot text proposal status:", v1TextStatus)
	println("[EXPECTED] snapshot param proposal status:", v1ParamStatus)
	println("[EXPECTED] snapshot param yea / nay:", v1ParamYea, v1ParamNay)
	println("[EXPECTED] snapshot param quorum:", v1ParamQuorum)
	println("[EXPECTED] snapshot admin vote weight:", v1AdminVoteWeight)
	println("[EXPECTED] snapshot user proposal count:", v1UserProposalCount)
	println("[EXPECTED] snapshot config version:", v1LatestConfigVer)
}

func upgradeTo(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	govGovernance.UpgradeImpl(cross(cur), packagePath)
	println("[EXPECTED] implementation:", govGovernance.GetImplementationPackagePath())
	uassert.Equal(t, packagePath, govGovernance.GetImplementationPackagePath())
}

func validateSnapshot() {
	// every getter error is asserted: a silent error would otherwise be turned
	// into a zero value and could hide a missing or reshaped record
	proposer, err := govGovernance.GetProposerByProposalId(paramProposalId)
	uassert.NoError(t, err)
	title, err := govGovernance.GetTitleByProposalId(paramProposalId)
	uassert.NoError(t, err)
	description, err := govGovernance.GetDescriptionByProposalId(paramProposalId)
	uassert.NoError(t, err)
	proposalType, err := govGovernance.GetProposalTypeByProposalId(paramProposalId)
	uassert.NoError(t, err)
	yea, err := govGovernance.GetYeaByProposalId(paramProposalId)
	uassert.NoError(t, err)
	nay, err := govGovernance.GetNayByProposalId(paramProposalId)
	uassert.NoError(t, err)
	quorumAmount, err := govGovernance.GetQuorumAmountByProposalId(paramProposalId)
	uassert.NoError(t, err)
	status, err := govGovernance.GetProposalStatusByProposalId(paramProposalId)
	uassert.NoError(t, err)
	configVer, err := govGovernance.GetConfigVersionByProposalId(paramProposalId)
	uassert.NoError(t, err)
	voteWeight, err := govGovernance.GetVoteWeight(paramProposalId, adminAddr)
	uassert.NoError(t, err)
	votedAt, err := govGovernance.GetVotedAt(paramProposalId, adminAddr)
	uassert.NoError(t, err)
	textStatus, err := govGovernance.GetProposalStatusByProposalId(textProposalId)
	uassert.NoError(t, err)
	latestConfig, err := govGovernance.GetLatestConfig()
	uassert.NoError(t, err)
	_, err = govGovernance.GetConfig(v1LatestConfigVer)
	uassert.NoError(t, err)

	// compare the proposal ids themselves, not only how many there are
	proposalIDs := collectProposalIDs(0, 10)
	uassert.Equal(t, v1ProposalCount, govGovernance.GetProposals().Size())
	uassert.Equal(t, len(v1ProposalIDs), len(proposalIDs))
	for i, id := range v1ProposalIDs {
		uassert.Equal(t, id, proposalIDs[i])
	}
	uassert.Equal(t, v1TextStatus, textStatus)
	uassert.Equal(t, v1ParamProposer, proposer)
	uassert.Equal(t, v1ParamTitle, title)
	uassert.Equal(t, v1ParamDescription, description)
	uassert.Equal(t, v1ParamType, proposalType.String())
	uassert.Equal(t, v1ParamYea, yea)
	uassert.Equal(t, v1ParamNay, nay)
	uassert.Equal(t, v1ParamQuorum, quorumAmount)
	uassert.Equal(t, v1ParamStatus, status)
	uassert.Equal(t, v1ParamConfigVer, configVer)
	uassert.Equal(t, v1AdminVoteWeight, voteWeight)
	uassert.Equal(t, v1AdminVotedAt, votedAt)
	uassert.Equal(t, v1UserProposalCount, userProposalCount(adminAddr))
	uassert.Equal(t, v1LatestConfigVer, govGovernance.GetLatestConfigVersion())
	uassert.Equal(t, v1VotingPeriod, latestConfig.VotingPeriod)
	uassert.True(t, govGovernance.ExistsProposal(paramProposalId))
	uassert.True(t, govGovernance.ExistsVotingInfo(paramProposalId, adminAddr))
	uassert.False(t, govGovernance.ExistsVotingInfo(paramProposalId, aliceAddr))

	println("[EXPECTED] proposal count:", govGovernance.GetProposals().Size())
	for _, id := range proposalIDs {
		println("[EXPECTED] proposal id after upgrade:", id)
	}
	println("[EXPECTED] param proposal title:", title)
	println("[EXPECTED] param proposal yea / nay:", yea, nay)
	println("[EXPECTED] admin vote weight:", voteWeight)
	println("[EXPECTED] every v1 proposal value survived the upgrade")
}

func executeAndReconfigure(cur realm) {
	// the proposal becomes executable after the voting period plus the delay
	testing.SkipHeights((config.VotingPeriod + config.ExecutionDelay) / blockTimeSeconds)

	unStakingFeeBefore := staker.GetUnstakingFee()

	testing.SetRealm(adminRealm)
	executedId := govGovernance.Execute(cross(cur), paramProposalId)
	testing.SkipHeights(1)

	status, _ := govGovernance.GetProposalStatusByProposalId(paramProposalId)
	println("[EXPECTED] executed proposal id:", executedId)
	println("[EXPECTED] param proposal status after execute:", status)
	println("[EXPECTED] staker unstaking fee before / after:", unStakingFeeBefore, staker.GetUnstakingFee())

	// governance drove a setter on another upgradeable contract
	uassert.Equal(t, newUnStakingFee, staker.GetUnstakingFee())
	uassert.Equal(t, paramProposalId, executedId)

	newVersion := govGovernance.Reconfigure(
		cross(cur),
		config.VotingStartDelay,
		config.VotingPeriod,
		config.VotingWeightSmoothingDuration,
		config.Quorum,
		config.ProposalCreationThreshold,
		config.ExecutionDelay,
		config.ExecutionWindow,
	)
	testing.SkipHeights(1)
	latestConfig, err := govGovernance.GetLatestConfig()
	uassert.NoError(t, err)

	println("[EXPECTED] config version after reconfigure:", newVersion)
	println("[EXPECTED] latest config voting period:", latestConfig.VotingPeriod)

	uassert.Equal(t, v1LatestConfigVer+1, newVersion)
	uassert.Equal(t, v1VotingPeriod, latestConfig.VotingPeriod)
}

func assertAborts(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", callback)
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Initialize governance contract with v1
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/governance/v1
// [EXPECTED] config version: 1
// [EXPECTED] voting period / quorum / threshold: 604800 50 1000000000
//
// [SCENARIO] 2. Delegate GNS so the proposal threshold is met
// [EXPECTED] total delegated: 5000000000
//
// [SCENARIO] 3. Create and cancel a text proposal with v1
// [EXPECTED] text proposal id: 1
// [EXPECTED] text proposal title: text proposal
// [EXPECTED] text proposal proposer is admin: true
// [EXPECTED] text proposal status: canceled
//
// [SCENARIO] 4. Create and vote on a parameter change proposal with v1
// [EXPECTED] param proposal id: 2
// [EXPECTED] param proposal type: ParameterChange
// [EXPECTED] yea / nay: 5000000000 0
// [EXPECTED] quorum / max / yes / no: 2500000000 5000000000 5000000000 0
// [EXPECTED] admin vote weight: 5000000000
// [EXPECTED] voting info count: 1
// [EXPECTED] admin has voted: true
//
// [SCENARIO] 5. Snapshot v1 data through the getters
// [EXPECTED] snapshot proposal count: 2
// [EXPECTED] snapshot proposal ids: 2
// [EXPECTED] snapshot proposal id: 1
// [EXPECTED] snapshot proposal id: 2
// [EXPECTED] snapshot text proposal status: canceled
// [EXPECTED] snapshot param proposal status: active
// [EXPECTED] snapshot param yea / nay: 5000000000 0
// [EXPECTED] snapshot param quorum: 2500000000
// [EXPECTED] snapshot admin vote weight: 5000000000
// [EXPECTED] snapshot user proposal count: 1
// [EXPECTED] snapshot config version: 1
//
// [SCENARIO] 6. Upgrade to v2_invalid
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/governance/v2_invalid
//
// [SCENARIO] 7. Mutating calls must be blocked by v2_invalid
// [EXPECTED] ProposeText is blocked by v2_invalid
// [EXPECTED] Execute is blocked by v2_invalid
//
// [SCENARIO] 8. Upgrade to v3_valid
// [EXPECTED] implementation: gno.land/r/gnoswap/gov/governance/v3_valid
//
// [SCENARIO] 9. Validate the v1 proposal data through v3_valid
// [EXPECTED] proposal count: 2
// [EXPECTED] proposal id after upgrade: 1
// [EXPECTED] proposal id after upgrade: 2
// [EXPECTED] param proposal title: raise the unstaking fee
// [EXPECTED] param proposal yea / nay: 5000000000 0
// [EXPECTED] admin vote weight: 5000000000
// [EXPECTED] every v1 proposal value survived the upgrade
//
// [SCENARIO] 10. Finish the v1 proposal lifecycle with v3_valid
// [EXPECTED] executed proposal id: 2
// [EXPECTED] param proposal status after execute: executed
// [EXPECTED] staker unstaking fee before / after: 100 150
// [EXPECTED] config version after reconfigure: 2
// [EXPECTED] latest config voting period: 604800

// collectProposalIDs pages the read-only proposal view and returns the IDs its
// keys encode.
func collectProposalIDs(offset, count int) []int64 {
	ids := []int64{}
	govGovernance.GetProposals().IterateByOffset(offset, count, func(key string, _ any) bool {
		id, err := strconv.ParseInt(key, 10, 64)
		if err != nil {
			return false
		}

		ids = append(ids, id)

		return false
	})

	return ids
}

// userProposalCount reads how many proposals a user created through the
// read-only view.
func userProposalCount(user address) int {
	proposalIDs, ok := govGovernance.GetUserProposals().Get(user.String()).([]int64)
	if !ok {
		return 0
	}

	return len(proposalIDs)
}
