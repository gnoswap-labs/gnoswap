package governance

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	cn "gno.land/r/gnoswap/v1/common"
	cp "gno.land/r/gnoswap/v1/community_pool"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"
)

// Execute executes the given proposal.
// It checks various conditions such as voting period, execution window, quorum, and majority.
// ref: https://docs.gnoswap.io/contracts/governance/execute.gno#execute
func Execute(proposalId uint64) {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()

	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("execute.gno__Execute() || proposalId(%d) does not exist, failed to execute", proposalId),
		))
	}

	if proposal.ProposalType == "TEXT" {
		panic(addDetailToError(
			errTextProposalNotExecutable,
			ufmt.Sprintf("execute.gno__Execute() || proposalId(%d) is a TEXT proposal, not executable", proposalId),
		))
	}

	if proposal.ExecutionState.Executed || proposal.ExecutionState.Canceled || proposal.ExecutionState.Rejected {
		panic(addDetailToError(
			errUnableToExecuteProposal,
			ufmt.Sprintf("execute.gno__Execute() || proposalId(%d) has already executed(%t) or canceled(%t) or rejected(%t), failed to execute", proposalId, proposal.ExecutionState.Executed, proposal.ExecutionState.Canceled, proposal.ExecutionState.Rejected),
		))
	}

	if !proposal.ExecutionState.Passed {
		panic(addDetailToError(
			errUnableToExecuteProposal,
			ufmt.Sprintf("execute.gno__Execute() || proposalId(%d) has not passed, failed to execute", proposalId),
		))
	}

	now := uint64(time.Now().Unix())

	config := GetConfigVersion(proposal.ConfigVersion)
	votingEnd := proposal.ExecutionState.CreatedAt + config.VotingStartDelay + config.VotingPeriod
	windowStart := votingEnd + config.ExecutionDelay
	if now < windowStart {
		panic(addDetailToError(
			errBeforeProposalExecutionTime,
			ufmt.Sprintf("execute.gno__Execute() || EXECUTION_WINDOW_NOT_STARTED (now(%d) < windowStart(%d))", now, windowStart),
		))
	}

	windowEnd := windowStart + config.ExecutionWindow
	if now >= windowEnd {
		panic(addDetailToError(
			errProposalExecutionTimeExpired,
			ufmt.Sprintf("execute.gno__Execute() || EXECUTION_WINDOW_OVER (now(%d) >= windowEnd(%d))", now, windowEnd),
		))
	}

	yeaUint := proposal.Yea.Uint64()
	nayUint := proposal.Nay.Uint64()
	quorumUint := proposal.QuorumAmount

	if yeaUint < quorumUint {
		panic(addDetailToError(
			errProposalQuorumNotSatisfied,
			ufmt.Sprintf("execute.gno__Execute() || QUORUM_NOT_MET (yes(%d) < quorum(%d))", yeaUint, quorumUint),
		))
	}

	if yeaUint < nayUint {
		panic(addDetailToError(
			errMoreNoVotesThanYesVotes,
			ufmt.Sprintf("execute.gno__Execute() || NO_MAJORITY (yes(%d) < no(%d))", yeaUint, nayUint),
		))
	}

	if proposal.ProposalType == "COMMUNITY_POOL_SPEND" {
		// check if the token is registered to community pool
		registered := cp.GetRegisteredTokens()
		if !contains(registered, proposal.CommunityPoolSpend.TokenPath) {
			panic(addDetailToError(
				errNotRegisteredToCommunityPool,
				ufmt.Sprintf("execute.gno__Execute() || token(%s) is not registered to community_pool", proposal.CommunityPoolSpend.TokenPath),
			))
		}

		// trigger community pool spend
		cp.TransferToken(proposal.CommunityPoolSpend.TokenPath, proposal.CommunityPoolSpend.To, proposal.CommunityPoolSpend.Amount)
	}

	if proposal.ProposalType == "PARAMETER_CHANGE" {
		// trigger parameter change
		executeParameterChange(proposal.Execution.Msgs)
	}

	proposal.ExecutionState.Executed = true
	proposal.ExecutionState.ExecutedAt = now
	proposal.ExecutionState.Upcoming = false
	proposal.ExecutionState.Active = false
	proposals[proposalId] = proposal

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Execute",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"proposalId", ufmt.Sprintf("%d", proposalId),
	)
}

func callableMsg(pkgPath, function, params string) bool {
	param := strings.Split(params, ",")

	switch pkgPath {

	case consts.EMISSION_PATH:
		switch function {
		case "ChangeDistributionPct":
			if len(param) != 8 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 8 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.GNS_PATH:
		switch function {
		case "SetAvgBlockTimeInMs":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.GOV_GOVERNANCE_PATH:
		switch function {
		case "Reconfigure":
			if len(param) != 7 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 7 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.POOL_PATH:
		switch function {
		case "SetFeeProtocol":
			if len(param) != 2 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "SetPoolCreationFee":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "SetWithdrawalFee":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.PROTOCOL_FEE_PATH:
		switch function {
		case "SetDevOpsPct":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.ROUTER_PATH:
		switch function {
		case "SetSwapFee":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.STAKER_PATH:
		switch function {
		case "SetDepositGnsAmount":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "SetPoolTier":
			if len(param) != 2 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "ChangePoolTier":
			if len(param) != 2 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "RemovePoolTier":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "SetUnstakingFee":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		case "SetWarmUp":
			if len(param) != 2 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true

		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.COMMON_PATH:
		switch function {
		case "SetHalt":
			if len(param) != 1 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	case consts.COMMUNITY_POOL_PATH:
		switch function {
		case "TransferToken":
			if len(param) != 3 {
				panic(addDetailToError(
					errInvalidFunctionParameters,
					ufmt.Sprintf("execute.gno__callableMsg() || len(param) should be 3 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function),
				))
			}
			return true
		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__callableMsg() || invalid function %s for pkgPath %s", function, pkgPath),
			))
		}

	default:
		panic(addDetailToError(
			errNonExecutableFunction,
			ufmt.Sprintf("execute.gno__callableMsg() || invalid pkgPath(%s)", pkgPath),
		))
	}
}

func executeParameterChange(msgs []string) {
	for _, msg := range msgs {
		splitExe := strings.Split(msg, "*EXE*")
		if len(splitExe) != 3 {
			panic(addDetailToError(
				errInvalidInput,
				ufmt.Sprintf("execute.gno__executeParameterChange() || invalid execution(%s) to split by *EXE*, seems like param didn't inputed", msg),
			))
		}

		pkgPath := splitExe[0]
		funcName := splitExe[1]
		paramsStr := splitExe[2]
		params := strings.Split(paramsStr, ",")

		switch pkgPath {
		case consts.COMMUNITY_POOL_PATH:
			switch funcName {
			case "TransferToken":
				pkgPath, to, amount := handleCommunityPoolTransferToken(params)
				cp.TransferToken(pkgPath, to, amount)
			}

		case consts.EMISSION_PATH:
			switch funcName {
			case "ChangeDistributionPct":
				target01, pct01, target02, pct02, target03, pct03, target04, pct04 := handleEmissionChangeDistributionPct(params)
				en.ChangeDistributionPct(target01, pct01, target02, pct02, target03, pct03, target04, pct04)
			}

		case consts.GNS_PATH:
			switch funcName {
			case "SetAvgBlockTimeInMs":
				ms := handleSetAvgBlockTimeInMs(params)
				gns.SetAvgBlockTimeInMs(ms)
			}

		case consts.GOV_GOVERNANCE_PATH:
			switch funcName {
			case "Reconfigure":
				votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow := handleGovernanceReconfigure(params)
				reconfigure(votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow)
			}

		case consts.POOL_PATH:
			switch funcName {
			case "SetFeeProtocol":
				feeProtocol0, feeProtocol1 := handlePoolSetFeeProtocol(params)
				pl.SetFeeProtocol(feeProtocol0, feeProtocol1)
			case "SetPoolCreationFee":
				fee := handleSingleUint64(params)
				pl.SetPoolCreationFee(fee)
			case "SetWithdrawalFee":
				fee := handleSingleUint64(params)
				pl.SetWithdrawalFee(fee)
			}

		case consts.PROTOCOL_FEE_PATH:
			switch funcName {
			case "SetDevOpsPct":
				pct := handleSingleUint64(params)
				pf.SetDevOpsPct(pct)
			}

		case consts.ROUTER_PATH:
			switch funcName {
			case "SetSwapFee":
				fee := handleSingleUint64(params)
				rr.SetSwapFee(fee)
			}

		case consts.STAKER_PATH:
			switch funcName {
			case "SetDepositGnsAmount":
				amount := handleSingleUint64(params)
				sr.SetDepositGnsAmount(amount)
			case "SetPoolTier":
				poolPath, tier := handlePoolPathTier(params)
				sr.SetPoolTier(poolPath, tier)
			case "ChangePoolTier":
				poolPath, tier := handlePoolPathTier(params)
				sr.ChangePoolTier(poolPath, tier)
			case "RemovePoolTier":
				sr.RemovePoolTier(params[0]) // poolPath
			case "SetUnstakingFee":
				fee := handleSingleUint64(params)
				sr.SetUnstakingFee(fee)
			case "SetWarmUp":
				percent, block := handleTwoInt64(params)
				sr.SetWarmUp(percent, block)
			}

		case consts.COMMON_PATH:
			switch funcName {
			case "SetHalt":
				halt := handleSingleBool(params)
				cn.SetHalt(halt)
			}

		default:
			panic(addDetailToError(
				errNonExecutableFunction,
				ufmt.Sprintf("execute.gno__executeParameterChange() || invalid package path(%s) and function name(%s)", pkgPath, funcName),
			))
		}

	}
}

func handleCommunityPoolTransferToken(params []string) (string, std.Address, uint64) {
	p2, err := strconv.ParseUint(params[2], 10, 64)
	if err != nil {
		panic(err)
	}
	return params[0], std.Address(params[1]), p2
}

func handleEmissionChangeDistributionPct(params []string) (
	int, uint64,
	int, uint64,
	int, uint64,
	int, uint64,
) {
	target01, err := strconv.ParseInt(params[0], 10, 64)
	if err != nil {
		panic(err)
	}
	pct01, err := strconv.ParseUint(params[1], 10, 64)
	if err != nil {
		panic(err)
	}

	target02 := strToInt(params[2])
	pct02, err := strconv.ParseUint(params[3], 10, 64)
	if err != nil {
		panic(err)
	}

	target03 := strToInt(params[4])
	pct03, err := strconv.ParseUint(params[5], 10, 64)
	if err != nil {
		panic(err)
	}

	target04 := strToInt(params[6])
	pct04, err := strconv.ParseUint(params[7], 10, 64)
	if err != nil {
		panic(err)
	}

	return int(target01), pct01, target02, pct02, target03, pct03, target04, pct04
}

func handleSetAvgBlockTimeInMs(params []string) int64 {
	res, err := strconv.ParseInt(params[0], 10, 64)
	if err != nil {
		panic(err)
	}
	return res
}

func handleGovernanceReconfigure(params []string) (
	uint64, uint64, uint64, uint64, uint64, uint64, uint64,
) {
	votingStartDelay, err := strconv.ParseUint(params[0], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	votingPeriod, err := strconv.ParseUint(params[1], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	votingWeightSmoothingDuration, err := strconv.ParseUint(params[2], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	quorum, err := strconv.ParseUint(params[3], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	proposalCreationThreshold, err := strconv.ParseUint(params[4], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	executionDelay, err := strconv.ParseUint(params[5], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	executionWindow, err := strconv.ParseUint(params[6], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	return votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow
}

func handlePoolSetFeeProtocol(params []string) (uint8, uint8) {
	feeProtocol0, err := strconv.ParseUint(params[0], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	feeProtocol1, err := strconv.ParseUint(params[1], 10, 64)
	if err != nil {
		panic(err.Error())
	}

	return uint8(feeProtocol0), uint8(feeProtocol1)
}

func handleSingleUint64(params []string) uint64 {
	res, err := strconv.ParseUint(params[0], 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return res
}

func handlePoolPathTier(params []string) (string, uint64) {
	res, err := strconv.ParseUint(params[1], 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return params[0], res
}

func handleTwoInt64(params []string) (int64, int64) {
	res0, err := strconv.ParseInt(params[0], 10, 64)
	if err != nil {
		panic(err.Error())
	}
	res1, err := strconv.ParseInt(params[1], 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return res0, res1
}

func handleSingleBool(params []string) bool {
	switch params[0] {
	case "true":
		return true
	case "false":
		return false
	default:
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("execute.gno__handleSingleBool() || invalid bool(%s)", params[0]),
		))
	}
}
