package governance

import (
	"std"
	"strings"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"
	gs "gno.land/r/gnoswap/v2/gov/staker"

	cn "gno.land/r/gnoswap/v2/common"
	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"
	pf "gno.land/r/gnoswap/v2/protocol_fee"
	rr "gno.land/r/gnoswap/v2/router"
	sr "gno.land/r/gnoswap/v2/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

func TestProposeParameterChange_Emission_ChangeDistributionPct(t *testing.T) {
	t.Run("Propose with insufficient delegation", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "THRESHOLD") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		ProposeParameterChange("test_title", "test_description", "pkgPath", "function", "param")
	})

	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		gns.Approve(a2u(consts.GOV_STAKER_ADDR), uint64(1_000_000))
		gs.Delegate(gsa, uint64(1_000_000))
		std.TestSkipHeights(1)

		proposalID := ProposeParameterChange("test_title", "test_description", consts.EMISSION_PATH, "ChangeDistributionPct", "1*GOV*7000*GOV*2*GOV*1500*GOV*3*GOV*1000*GOV*4*GOV*500")
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

		if proposal.ProposalType != "PARAMETER_CHANGE" {
			t.Errorf("Incorrect proposal type. Expected PARAMETER_CHANGE, got %v", proposal.ProposalType)
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
	})

	t.Run("prpose with active proposal", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("The code did not panic")
			} else if !strings.Contains(string(r), "PROPOSER_HAS_UPCOMING_OR_ACTIVE_PROPOSAL") {
				t.Errorf("Unexpected panic message: %v", r)
			}
		}()

		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		proposalID := ProposeParameterChange("test_title", "test_description", consts.EMISSION_PATH, "ChangeDistributionPct", "1*GOV*7000*GOV*2*GOV*1500*GOV*3*GOV*1000*GOV*4*GOV*500")
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()

		proposal := proposals[proposalId]
		if !proposal.ExecutionState.Passed {
			t.Errorf("Proposal execute state(passed) not set correctly")
		}
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, en.GetDistributionPct(1), uint64(7500))
		shouldEQ(t, en.GetDistributionPct(2), uint64(2000))
		shouldEQ(t, en.GetDistributionPct(3), uint64(500))
		shouldEQ(t, en.GetDistributionPct(4), uint64(0))

		Execute(proposalId)

		shouldEQ(t, en.GetDistributionPct(1), uint64(7000))
		shouldEQ(t, en.GetDistributionPct(2), uint64(1500))
		shouldEQ(t, en.GetDistributionPct(3), uint64(1000))
		shouldEQ(t, en.GetDistributionPct(4), uint64(500))

		proposal := proposals[proposalId]
		if !proposal.ExecutionState.Executed {
			t.Errorf("Proposal execute state(executed) not set correctly")
		}
	})
}

func TestProposeParameterChange_GNS_SetAvgBlockTimeInMs(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.GNS_PATH,
			"SetAvgBlockTimeInMs",
			"5000",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, gns.GetAvgBlockTimeInMs(), int64(2000))
		Execute(proposalId)
		shouldEQ(t, gns.GetAvgBlockTimeInMs(), int64(5000))
	})
}

func TestProposeParameterChange_GOV_Reconfigure(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.GOV_GOVERNANCE_PATH,
			"Reconfigure",
			"123*GOV*456*GOV*789*GOV*1234*GOV*5678*GOV*12345*GOV*67890",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		oldConfig := GetConfigVersion(0)
		shouldEQ(t, oldConfig.VotingStartDelay, uint64(100))
		shouldEQ(t, oldConfig.VotingPeriod, uint64(1000))
		shouldEQ(t, oldConfig.VotingWeightSmoothingDuration, uint64(100))
		shouldEQ(t, oldConfig.Quorum, uint64(500))
		shouldEQ(t, oldConfig.ProposalCreationThreshold, uint64(100))
		shouldEQ(t, oldConfig.ExecutionDelay, uint64(100))
		shouldEQ(t, oldConfig.ExecutionWindow, uint64(1000))

		Execute(proposalId)

		newConfig := GetConfigVersion(0)
		shouldEQ(t, newConfig.VotingStartDelay, uint64(123))
		shouldEQ(t, newConfig.VotingPeriod, uint64(456))
		shouldEQ(t, newConfig.VotingWeightSmoothingDuration, uint64(789))
		shouldEQ(t, newConfig.Quorum, uint64(1234))
		shouldEQ(t, newConfig.ProposalCreationThreshold, uint64(5678))
		shouldEQ(t, newConfig.ExecutionDelay, uint64(12345))
		shouldEQ(t, newConfig.ExecutionWindow, uint64(67890))

		// overwrite latest config version to old one for further tests
		config.VotingStartDelay = 100
		config.VotingPeriod = 1000
		config.VotingWeightSmoothingDuration = 100
		config.Quorum = 500
		config.ProposalCreationThreshold = 100
		config.ExecutionDelay = 100
		config.ExecutionWindow = 1000
		configVersions[uint64(2)] = config
	})
}

func TestProposeParameterChange_Pool_SetFeeProtocol(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.POOL_PATH,
			"SetFeeProtocol",
			"4*GOV*4",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		Execute(proposalId)
	})
}

func TestProposeParameterChange_Pool_SetPoolCreationFee(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.POOL_PATH,
			"SetPoolCreationFee",
			"500",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, pl.GetPoolCreationFee(), uint64(100000000))
		Execute(proposalId)
		shouldEQ(t, pl.GetPoolCreationFee(), uint64(500))
	})
}

func TestProposeParameterChange_Pool_SetWithdrawalFee(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.POOL_PATH,
			"SetWithdrawalFee",
			"500",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, pl.GetWithdrawalFee(), uint64(100))
		Execute(proposalId)
		shouldEQ(t, pl.GetWithdrawalFee(), uint64(500))
	})
}

func TestProposeParameterChange_ProtocolFee_DistributeProtocolFee(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.PROTOCOL_FEE_PATH,
			"DistributeProtocolFee",
			"",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		// send some tokens to protocol fee address
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		foo.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), 1000)
		bar.Transfer(a2u(consts.PROTOCOL_FEE_ADDR), 1000)

		// check balances before execution
		shouldEQ(t, foo.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)), uint64(1000))
		shouldEQ(t, bar.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)), uint64(1000))

		shouldEQ(t, foo.BalanceOf(a2u(consts.DEV_OPS)), uint64(0))
		shouldEQ(t, bar.BalanceOf(a2u(consts.DEV_OPS)), uint64(0))
		shouldEQ(t, foo.BalanceOf(a2u(consts.GOV_STAKER_ADDR)), uint64(0))
		shouldEQ(t, bar.BalanceOf(a2u(consts.GOV_STAKER_ADDR)), uint64(0))

		Execute(proposalId)
		// 30% to dev ops, 70% to gov staker

		shouldEQ(t, foo.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)), uint64(0))
		shouldEQ(t, bar.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)), uint64(0))

		shouldEQ(t, foo.BalanceOf(a2u(consts.DEV_OPS)), uint64(300))
		shouldEQ(t, bar.BalanceOf(a2u(consts.DEV_OPS)), uint64(300))
		shouldEQ(t, foo.BalanceOf(a2u(consts.GOV_STAKER_ADDR)), uint64(700))
		shouldEQ(t, bar.BalanceOf(a2u(consts.GOV_STAKER_ADDR)), uint64(700))
	})
}

func TestProposeParameterChange_ProtocolFee_SetDevOpsPct(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.PROTOCOL_FEE_PATH,
			"SetDevOpsPct",
			"900",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, pf.GetDevOpsPct(), uint64(3000))

		Execute(proposalId)

		shouldEQ(t, pf.GetDevOpsPct(), uint64(900))
	})
}

func TestProposeParameterChange_Router_SetSwapFee(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.ROUTER_PATH,
			"SetSwapFee",
			"900",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, rr.GetSwapFee(), uint64(15))

		Execute(proposalId)

		shouldEQ(t, rr.GetSwapFee(), uint64(900))
	})
}

func TestProposeParameterChange_Staker_SetDepositGnsAmount(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"SetDepositGnsAmount",
			"900",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, sr.GetDepositGnsAmount(), uint64(1000000000))

		Execute(proposalId)

		shouldEQ(t, sr.GetDepositGnsAmount(), uint64(900))
	})
}

func TestProposeParameterChange_Staker_SetPoolTier(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"SetPoolTier",
			"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100*GOV*1",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		// create sample pool
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)
		pl.SetPoolCreationFee(0)
		pl.CreatePool(consts.WUGNOT_PATH, consts.GNS_PATH, 100, "79228162514264337593543950337")

		before := sr.GetPoolsWithTier()
		shouldEQ(t, len(before), 1)
		shouldEQ(t, before[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")

		Execute(proposalId)

		after := sr.GetPoolsWithTier()
		shouldEQ(t, len(after), 2)
		shouldEQ(t, after[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")
		shouldEQ(t, after[1], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100_1")
	})
}

func TestProposeParameterChange_Staker_ChangePoolTier(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"ChangePoolTier",
			"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100*GOV*3",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		before := sr.GetPoolsWithTier()
		shouldEQ(t, len(before), 2)
		shouldEQ(t, before[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")
		shouldEQ(t, before[1], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100_1")

		Execute(proposalId)

		after := sr.GetPoolsWithTier()
		shouldEQ(t, len(after), 2)
		shouldEQ(t, after[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")
		shouldEQ(t, after[1], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100_3")
	})
}

func TestProposeParameterChange_Staker_RemovePoolTier(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"RemovePoolTier",
			"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		before := sr.GetPoolsWithTier()
		shouldEQ(t, len(before), 2)
		shouldEQ(t, before[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")
		shouldEQ(t, before[1], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:100_3")

		Execute(proposalId)

		after := sr.GetPoolsWithTier()
		shouldEQ(t, len(after), 1)
		shouldEQ(t, after[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v2/gns:3000_1")
	})
}

func TestProposeParameterChange_Staker_SetUnstakingFee(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"SetUnstakingFee",
			"900",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, sr.GetUnstakingFee(), uint64(100))

		Execute(proposalId)

		shouldEQ(t, sr.GetUnstakingFee(), uint64(900))
	})
}

func TestProposeParameterChange_Staker_SetWarmUp(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.STAKER_PATH,
			"SetWarmUp",
			"100*GOV*1000",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, sr.GetWarmUp(100), int64(901))

		Execute(proposalId)

		shouldEQ(t, sr.GetWarmUp(100), int64(1000))
	})
}

func TestProposeParameterChange_Common_SetHalt(t *testing.T) {
	t.Run("Successful prpose", func(t *testing.T) {
		std.TestSetOrigCaller(gsa)
		std.TestSetRealm(gsaRealm)

		proposalID := ProposeParameterChange(
			"test_title",
			"test_description",
			consts.COMMON_PATH,
			"SetHalt",
			"true",
		)
	})

	t.Run("Vote proposal and make it pass status", func(t *testing.T) {
		// vote to pass it
		std.TestSkipHeights(51)
		voteKey := Vote(proposalId, true)
		voted := votes[voteKey]
		if voted != true {
			t.Errorf("Vote not set correctly")
		}

		std.TestSkipHeights(1000) // ends voting period
		updateProposalsState()
	})

	t.Run("Execute proposal", func(t *testing.T) {
		shouldEQ(t, cn.GetHalt(), false)

		Execute(proposalId)
		shouldEQ(t, cn.GetHalt(), true)
	})
}
