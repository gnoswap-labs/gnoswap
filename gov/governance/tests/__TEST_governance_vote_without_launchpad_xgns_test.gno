package governance

import (
	"std"
	"strings"
	"testing"
	"time"

	"gno.land/p/demo/testutils"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"

	gs "gno.land/r/gnoswap/v2/gov/staker"
	lp "gno.land/r/gnoswap/v2/launchpad"

	// grc20 tokens
	"gno.land/r/onbloc/obl"
)

var (
	dummyToAddr  = testutils.TestAddress("dummyTo")
	dummyToRealm = std.NewUserRealm(dummyToAddr)

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = std.NewUserRealm(dummyAddr)

	reDelegate = testutils.TestAddress("reDelegate")

	// launchpad
	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = std.NewUserRealm(projectAddr)

	user01      = testutils.TestAddress("user01")
	user01Realm = std.NewUserRealm(user01)
)

func TestCheckInitialGnsAndXGns(t *testing.T) {
	t.Run("check current gns and xgns (total/voting) supply", func(t *testing.T) {
		gnsTotal := gns.TotalSupply()
		gsaGnsBalance := gns.BalanceOf(a2u(gsa))
		xgnsTotal := xgns.TotalSupply()
		xgnsVoting := xgns.VotingSupply()
		shouldEQ(t, gnsTotal, uint64(100_000_000_000_000))
		shouldEQ(t, gsaGnsBalance, uint64(100_000_000_000_000))
		shouldEQ(t, xgnsTotal, uint64(0))
		shouldEQ(t, xgnsVoting, uint64(0))
	})
}

func TestLaunchPadCreateProject(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	obl.Approve(a2u(consts.LAUNCHPAD_ADDR), 1_000_000_000)
	projectId := lp.CreateProject(
		oblPath,
		projectAddr,
		uint64(1_000_000_000), // 1000000000
		"",
		"",
		uint64(10),                   // 100000000
		uint64(20),                   // 200000000
		uint64(70),                   // 700000000
		uint64(time.Now().Unix()+10), // 5 block later
	)
	shouldEQ(t, projectId, `gno.land/r/onbloc/obl:123`)
	std.TestSkipHeights(10) // active project
}

func TestLaunchPadDeposit(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)
	gns.Transfer(a2u(user01), uint64(1_000_000)) // to deposit

	std.TestSetRealm(user01Realm)
	std.TestSetOrigCaller(user01)
	gns.Approve(a2u(consts.LAUNCHPAD_ADDR), uint64(1_000_000))

	lp.DepositGns(
		`gno.land/r/onbloc/obl:123:30`,
		uint64(1_000_000), // this xGNS can not be used for voting
	)
	std.TestSkipHeights(1)
}

func TestCheckXGns(t *testing.T) {
	t.Run("check current gns and xgns (total/voting) supply (after launchpad project create and deposit)", func(t *testing.T) {
		gnsTotal := gns.TotalSupply()
		gsaGnsBalance := gns.BalanceOf(a2u(gsa))
		xgnsTotal := xgns.TotalSupply()
		xgnsVoting := xgns.VotingSupply()
		shouldEQ(t, gnsTotal, uint64(100_000_000_000_000))
		shouldEQ(t, gsaGnsBalance, uint64(99_999_999_000_000))
		shouldEQ(t, xgnsTotal, uint64(1_000_000))
		shouldEQ(t, xgnsVoting, uint64(0))
	})
}

func TestProposeText(t *testing.T) {
	t.Run("ProposeText with insufficient delegation", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "PROPOSER_HAS_NOT_ENOUGH_XGNS") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		ProposeText("title", "text")
	})

	t.Run("Successful text proposal", func(t *testing.T) {
		proposalsJson := GetProposals()
		if proposalsJson != `` {
			t.Errorf("Expected empty proposals, got %v", proposalsJson)
		}

		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		gns.Approve(a2u(consts.GOV_STAKER_ADDR), uint64(1_000_000))
		gs.Delegate(gsa, uint64(1_000_000))
		std.TestSkipHeights(11) // VotingWeightSmoothingDuration is 10 block

		proposalID := ProposeText("test_title", "test_description")
		if proposalID != 1 {
			t.Errorf("Expected proposal ID to be 1, got %d", proposalID)
		}

		proposal, exist := proposals[proposalId]
		if !exist {
			t.Errorf("Proposal not found after creation")
		}

		if proposal.Proposer != std.GetOrigCaller() {
			t.Errorf("Incorrect proposer. Expected %v, got %v", std.GetOrigCaller(), proposal.Proposer)
		}

		if proposal.ProposalType != "TEXT" {
			t.Errorf("Incorrect proposal type. Expected TEXT, got %v", proposal.ProposalType)
		}

		if !proposal.ExecutionState.Created {
			t.Errorf("Proposal execute state(created) not set correctly")
		}

		if !proposal.ExecutionState.Upcoming {
			t.Errorf("Proposal execute state(upcoming) not set correctly")
		}

		if proposal.Yea.Cmp(u256.NewUint(0)) != 0 || proposal.Nay.Cmp(u256.NewUint(0)) != 0 {
			t.Errorf("Initial vote counts should be zero")
		}

		if proposal.ConfigVersion != 1 {
			t.Errorf("Initial config version should be 1")
		}

		if proposal.Title != "test_title" {
			t.Errorf("Incorrect title. Expected test_title, got %v", proposal.Title)
		}

		if proposal.Description != "test_description" {
			t.Errorf("Incorrect text. Expected test_description, got %v", proposal.Description)
		}

		proposalsJson = GetProposals()
		if proposalsJson != `{"height":"145","now":"1234567934","proposals":[{"id":"1","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTY3OTM0IiwiVXBjb21pbmciOiJ0cnVlIiwiQWN0aXZlIjoiZmFsc2UiLCJWb3RpbmdTdGFydCI6IjEyMzQ1Njc5NDQiLCJWb3RpbmdFbmQiOiIxMjM0NTY3OTc0IiwiUGFzc2VkIjoiZmFsc2UiLCJQYXNzZWRBdCI6IjAiLCJSZWplY3RlZCI6ImZhbHNlIiwiUmVqZWN0ZWRBdCI6IjAiLCJDYW5jZWxlZCI6ImZhbHNlIiwiQ2FuY2VsZWRBdCI6IjAiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test_title","description":"test_description","vote":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMCIsIm5vIjoiMCJ9","extra":""}]}` {
			t.Errorf("Incorrect proposals json: %v", proposalsJson)
		}

		votesJson := GetVotesByAddress(gsa.String())
		if votesJson != `` {
			t.Errorf("Expected empty votes, got %v", votesJson)
		}
	})
}

func TestVote(t *testing.T) {
	t.Run("Vote non existent proposal", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "does not exist") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Vote(uint64(123), true)
	})

	proposalId := uint64(1) // text proposal id

	t.Run("Vote before voting period", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "not started yet") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Vote(proposalId, true)
	})

	t.Run("Successful vote YES", func(t *testing.T) {
		std.TestSkipHeights(11)

		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not recorded correctly")
		}

		proposal := proposals[proposalId]
		if proposal.Yea.Cmp(u256.NewUint(1_000_000)) != 0 {
			t.Errorf("Vote count not updated correctly", proposal.Yea.ToString())
		}

		if proposal.Nay.Cmp(u256.NewUint(0)) != 0 {
			t.Errorf("Vote count not updated correctly")
		}

		if proposal.ExecutionState.Upcoming {
			t.Errorf("Proposal should not be upcoming after vote")
		}

		if !proposal.ExecutionState.Active {
			t.Errorf("Proposal should be active after vote")
		}

		proposalsJson := GetProposals()
		if proposalsJson != `{"height":"156","now":"1234567956","proposals":[{"id":"1","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTY3OTM0IiwiVXBjb21pbmciOiJmYWxzZSIsIkFjdGl2ZSI6InRydWUiLCJWb3RpbmdTdGFydCI6IjEyMzQ1Njc5NDQiLCJWb3RpbmdFbmQiOiIxMjM0NTY3OTc0IiwiUGFzc2VkIjoiZmFsc2UiLCJQYXNzZWRBdCI6IjAiLCJSZWplY3RlZCI6ImZhbHNlIiwiUmVqZWN0ZWRBdCI6IjAiLCJDYW5jZWxlZCI6ImZhbHNlIiwiQ2FuY2VsZWRBdCI6IjAiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test_title","description":"test_description","vote":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMTAwMDAwMCIsIm5vIjoiMCJ9","extra":""}]}` {
			t.Errorf("Incorrect proposals json: %v", proposalsJson)
		}

		votesJson := GetVotesByAddress(gsa.String())
		if votesJson != `{"height":"156","now":"1234567956","votes":[{"proposalId":"1","voteYes":"true","voteWeight":"1000000","voteHeight":"156","voteTimestamp":"1234567956"}]}` {
			t.Errorf("Incorrect votes json: %v", votesJson)
		}

		voteJson := GetVoteStatusFromProposalById(proposalId)
		if voteJson != `{"height":"156","now":"1234567956","proposalId":"1","votes":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMTAwMDAwMCIsIm5vIjoiMCJ9"}` {
			t.Errorf("Incorrect vote json: %v", voteJson)
		}

		addrVotesJson := GetVotesByAddress(gsa.String())
		if addrVotesJson != `{"height":"156","now":"1234567956","votes":[{"proposalId":"1","voteYes":"true","voteWeight":"1000000","voteHeight":"156","voteTimestamp":"1234567956"}]}` {
			t.Errorf("Incorrect address votes json: %v", addrVotesJson)
		}

		addrVoteJson := GetVoteByAddressFromProposalById(gsa.String(), proposalId)
		if addrVoteJson != `{"height":"156","now":"1234567956","votes":[{"proposalId":"1","voteYes":"true","voteWeight":"1000000","voteHeight":"156","voteTimestamp":"1234567956"}]}` {
			t.Errorf("Incorrect address vote json: %v", addrVoteJson)
		}
	})

	t.Run("Vote twice", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "already voted") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Vote(proposalId, true)
	})

	t.Run("Vote after voting period", func(t *testing.T) {
		std.TestSkipHeights(2001)

		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "has ended") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Vote(proposalId, true)
	})

	t.Run("Proposal status after voting period", func(t *testing.T) {
		updateProposalsState()

		proposal := proposals[proposalId]
		if proposal.ExecutionState.Active {
			t.Errorf("Proposal should not be active after voting period")
		}

		if !proposal.ExecutionState.Passed {
			t.Errorf("Proposal should be passed")
		}

		if proposal.ExecutionState.Rejected {
			t.Errorf("Proposal should not be rejected")
		}

		if proposal.ExecutionState.Executed {
			t.Errorf("Proposal should not be executed, #1 is text proposal and should not be executed")
		}
	})
}

func TestCancel(t *testing.T) {
	// new text proposal #2
	proposalId := ProposeText("test2_title", "test2_description")
	if proposalId != 2 {
		t.Errorf("Expected proposal ID to be 2, got %d", proposalId)
	}

	t.Run("Cancel non existent proposal", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "does not exist") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Cancel(uint64(123))
	})

	t.Run("Successful cancel", func(t *testing.T) {
		Cancel(proposalId)
		proposalsJson := GetProposals()
		if proposalsJson != `{"height":"2157","now":"1234571958","proposals":[{"id":"1","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTY3OTM0IiwiVXBjb21pbmciOiJmYWxzZSIsIkFjdGl2ZSI6ImZhbHNlIiwiVm90aW5nU3RhcnQiOiIxMjM0NTY3OTQ0IiwiVm90aW5nRW5kIjoiMTIzNDU2Nzk3NCIsIlBhc3NlZCI6InRydWUiLCJQYXNzZWRBdCI6IjEyMzQ1NzE5NTgiLCJSZWplY3RlZCI6ImZhbHNlIiwiUmVqZWN0ZWRBdCI6IjAiLCJDYW5jZWxlZCI6ImZhbHNlIiwiQ2FuY2VsZWRBdCI6IjAiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test_title","description":"test_description","vote":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMTAwMDAwMCIsIm5vIjoiMCJ9","extra":""},{"id":"2","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTcxOTU4IiwiVXBjb21pbmciOiJmYWxzZSIsIkFjdGl2ZSI6ImZhbHNlIiwiVm90aW5nU3RhcnQiOiIxMjM0NTcxOTY4IiwiVm90aW5nRW5kIjoiMTIzNDU3MTk5OCIsIlBhc3NlZCI6ImZhbHNlIiwiUGFzc2VkQXQiOiIwIiwiUmVqZWN0ZWQiOiJmYWxzZSIsIlJlamVjdGVkQXQiOiIwIiwiQ2FuY2VsZWQiOiJ0cnVlIiwiQ2FuY2VsZWRBdCI6IjEyMzQ1NzE5NTgiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test2_title","description":"test2_description","vote":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMCIsIm5vIjoiMCJ9","extra":""}]}` {
			t.Errorf("Incorrect proposals json: %v", proposalsJson)
		}

		proposalJson := GetProposalById(proposalId)
		// vote quorum is 50% of total voting power
		// which means xgns's balance of launchpad won't be affected
		if proposalJson != `{"height":"2157","now":"1234571958","proposals":[{"id":"2","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTcxOTU4IiwiVXBjb21pbmciOiJmYWxzZSIsIkFjdGl2ZSI6ImZhbHNlIiwiVm90aW5nU3RhcnQiOiIxMjM0NTcxOTY4IiwiVm90aW5nRW5kIjoiMTIzNDU3MTk5OCIsIlBhc3NlZCI6ImZhbHNlIiwiUGFzc2VkQXQiOiIwIiwiUmVqZWN0ZWQiOiJmYWxzZSIsIlJlamVjdGVkQXQiOiIwIiwiQ2FuY2VsZWQiOiJ0cnVlIiwiQ2FuY2VsZWRBdCI6IjEyMzQ1NzE5NTgiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test2_title","description":"test2_description","vote":"eyJxdW9ydW0iOiI1MDAwMDAiLCJtYXgiOiIxMDAwMDAwIiwieWVzIjoiMCIsIm5vIjoiMCJ9","extra":""}]}` {
			t.Errorf("Incorrect proposal json: %v", proposalJson)
		}

		proposal := proposals[proposalId]
		if !proposal.ExecutionState.Canceled {
			t.Errorf("Proposal should be cancelled")
		}

		if proposal.ExecutionState.Active {
			t.Errorf("Proposal should not be active")
		}

		if proposal.ExecutionState.Upcoming {
			t.Errorf("Proposal should not be upcoming")
		}
	})

	t.Run("Cancel already canceled proposal", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "already canceled") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Cancel(proposalId)
	})

	t.Run("Cancle after voting period", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "already started") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		// new text proposal #3
		proposalId := ProposeText("test3_title", "test3_description")
		std.TestSkipHeights(11)
		Cancel(proposalId)
	})
}

func TestExecute(t *testing.T) {
	proposalId := uint64(1) // text proposal id

	t.Run("Execute text proposal", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "not executable") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		Execute(proposalId)
	})
}

func TestNoBehaviourProposal(t *testing.T) {
	t.Run("Successful text proposal", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		gns.Approve(a2u(consts.GOV_STAKER_ADDR), uint64(1_000_000))
		gs.Delegate(gsa, uint64(1_000_000))
		std.TestSkipHeights(11) // VotingWeightSmoothingDuration is 10 block

		proposalID := ProposeText("test_title", "test_description")
		if proposalID != 4 {
			t.Errorf("Expected proposal ID to be 4, got %d", proposalID)
		}

		proposal, exist := proposals[proposalId]
		if !exist {
			t.Errorf("Proposal not found after creation")
		}

		if proposal.Proposer != std.GetOrigCaller() {
			t.Errorf("Incorrect proposer. Expected %v, got %v", std.GetOrigCaller(), proposal.Proposer)
		}

		if proposal.ProposalType != "TEXT" {
			t.Errorf("Incorrect proposal type. Expected TEXT, got %v", proposal.ProposalType)
		}

		if !proposal.ExecutionState.Created {
			t.Errorf("Proposal execute state(created) not set correctly")
		}

		if !proposal.ExecutionState.Upcoming {
			t.Errorf("Proposal execute state(upcoming) not set correctly")
		}

		if proposal.Yea.Cmp(u256.NewUint(0)) != 0 || proposal.Nay.Cmp(u256.NewUint(0)) != 0 {
			t.Errorf("Initial vote counts should be zero")
		}

		if proposal.ConfigVersion != 1 {
			t.Errorf("Initial config version should be 1")
		}

		if proposal.Title != "test_title" {
			t.Errorf("Incorrect title. Expected test_title, got %v", proposal.Title)
		}

		if proposal.Description != "test_description" {
			t.Errorf("Incorrect text. Expected test_description, got %v", proposal.Description)
		}

		proposalsJson := GetProposalById(4)
		if proposalsJson != `{"height":"2179","now":"1234572002","proposals":[{"id":"4","configVersion":"1","proposer":"g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c","status":"eyJDcmVhdGVkQXQiOiIxMjM0NTcyMDAyIiwiVXBjb21pbmciOiJ0cnVlIiwiQWN0aXZlIjoiZmFsc2UiLCJWb3RpbmdTdGFydCI6IjEyMzQ1NzIwMTIiLCJWb3RpbmdFbmQiOiIxMjM0NTcyMDQyIiwiUGFzc2VkIjoiZmFsc2UiLCJQYXNzZWRBdCI6IjAiLCJSZWplY3RlZCI6ImZhbHNlIiwiUmVqZWN0ZWRBdCI6IjAiLCJDYW5jZWxlZCI6ImZhbHNlIiwiQ2FuY2VsZWRBdCI6IjAiLCJFeGVjdXRlZCI6ImZhbHNlIiwiRXhlY3V0ZWRBdCI6IjAiLCJFeHBpcmVkIjoiZmFsc2UiLCJFeHBpcmVkQXQiOiIwIn0=","type":"TEXT","title":"test_title","description":"test_description","vote":"eyJxdW9ydW0iOiIxMDAwMDAwIiwibWF4IjoiMjAwMDAwMCIsInllcyI6IjAiLCJubyI6IjAifQ==","extra":""}]}` {
			t.Errorf("Incorrect proposals json: %v", proposalsJson)
		}

		// DO NOTHING
		// JUST SKIP BUNCH OF TIME ( over voting period )
		std.TestSkipHeights(500)

		// CREATE NEW PROPOSAL
		proposalID = ProposeText("test_title", "test_description")
		if proposalID != 5 {
			t.Errorf("Expected proposal ID to be 5, got %d", proposalID)
		}
	})
}

func TestMultipleProposalFromSameAddress(t *testing.T) {
	t.Run("Successful two text proposal", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeText("test_title", "test_description")
		if proposalID != 6 {
			t.Errorf("Expected proposal ID to be 6, got %d", proposalID)
		}

		proposalID = ProposeText("test_title", "test_description")
		if proposalID != 7 {
			t.Errorf("Expected proposal ID to be 7, got %d", proposalID)
		}
	})
}
