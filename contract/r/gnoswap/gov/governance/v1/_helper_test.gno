package v1

import (
	"testing"

	"gno.land/p/onbloc/json"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gov/governance"

	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

var (
	admin, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

	fooPath string = "gno.land/r/onbloc/foo"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	quxPath string = "gno.land/r/onbloc/qux"

	oblPath string = "gno.land/r/onbloc/obl"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
)

// Realms to mock frames
var (
	adminRealm = testing.NewUserRealm(admin)

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	routerPath = "gno.land/r/gnoswap/router"
	rouRealm   = testing.NewCodeRealm(routerPath)

	stakerPath = "gno.land/r/gnoswap/staker"
	stkRealm   = testing.NewCodeRealm(stakerPath)

	govPath  = "gno.land/r/gnoswap/gov/governance"
	govRealm = testing.NewCodeRealm(govPath)

	govGovernanceAddr, _ = access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	launchpadAddr, _     = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
)

/* HELPER */
func unmarshal(data string) *json.Node {
	return json.Must(json.Unmarshal([]byte(data)))
}

func createMockGovernanceStore() *mockGovernanceStore {
	return &mockGovernanceStore{
		configCounter:           governance.NewCounter(),
		proposalCounter:         governance.NewCounter(),
		configs:                 governance.NewConfigTree(),
		proposals:               governance.NewProposalTree(),
		proposalUserVotingInfos: governance.NewProposalUserVotingInfoTree(),
		userProposals:           governance.NewUserProposalTree(),
	}
}

func newTestProposal(
	id int64,
	status *governance.ProposalStatus,
	metadata *governance.ProposalMetadata,
	data *governance.ProposalData,
	proposer address,
	configVersion int64,
	snapshotTime int64,
) *governance.Proposal {
	// Use snapshotTime as the proposal creation time and 100 as default createdHeight for tests
	return governance.NewProposal(
		id,
		status,
		metadata,
		data,
		proposer,
		configVersion,
		snapshotTime,
		100, // createdHeight
	)
}
// Crossing test wrappers.
//
// The governance impl methods read their caller via rlm.Previous(). To
// simulate a specific caller, tests set the caller realm with
// testing.SetRealm(...) and then invoke the method through one of these
// crossing wrappers using mockX(cross(cur), gov, ...). The cross(cur)
// mints a fresh cur whose previous realm is the simulated caller, which
// the wrapper threads into the impl method as `cur` so the impl's
// rlm.Previous() resolves to that caller.
func mockReconfigure(
	cur realm,
	gv *governanceV1,
	votingStartDelay, votingPeriod, votingWeightSmoothingDuration,
	quorum, proposalCreationThreshold, executionDelay, executionWindow int64,
) int64 {
	return gv.Reconfigure(
		0, cur,
		votingStartDelay,
		votingPeriod,
		votingWeightSmoothingDuration,
		quorum,
		proposalCreationThreshold,
		executionDelay,
		executionWindow,
	)
}

func mockExecute(cur realm, gv *governanceV1, proposalID int64) int64 {
	return gv.Execute(0, cur, proposalID)
}

func mockCancel(cur realm, gv *governanceV1, proposalID int64) int64 {
	return gv.Cancel(0, cur, proposalID)
}

func mockVote(cur realm, gv *governanceV1, proposalID int64, yes bool) string {
	return gv.Vote(0, cur, proposalID, yes)
}

func mockProposeText(cur realm, gv *governanceV1, title, description string) int64 {
	return gv.ProposeText(0, cur, title, description)
}

func mockProposeCommunityPoolSpend(
	cur realm,
	gv *governanceV1,
	title, description string,
	to address,
	tokenPath string,
	amount int64,
) int64 {
	return gv.ProposeCommunityPoolSpend(0, cur, title, description, to, tokenPath, amount)
}

func mockProposeParameterChange(
	cur realm,
	gv *governanceV1,
	title, description string,
	numToExecute int64,
	executions string,
) int64 {
	return gv.ProposeParameterChange(0, cur, title, description, numToExecute, executions)
}
