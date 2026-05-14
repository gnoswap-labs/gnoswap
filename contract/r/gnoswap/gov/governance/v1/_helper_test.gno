package v1

import (
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
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

	btcPath string = "gno.land/r/gnoswap/test_token/btc"
	atomPath string = "gno.land/r/gnoswap/test_token/atom"
	atonePath string = "gno.land/r/gnoswap/test_token/atone"
	solPath string = "gno.land/r/gnoswap/test_token/sol"

	ethPath string = "gno.land/r/gnoswap/test_token/eth"

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
		configs:                 bptree.NewBPTreeN(16),
		proposals:               bptree.NewBPTreeN(16),
		proposalUserVotingInfos: bptree.NewBPTreeN(16),
		userProposals:           bptree.NewBPTreeN(16),
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
