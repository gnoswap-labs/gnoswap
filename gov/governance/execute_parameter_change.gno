package governance

import (
	"strings"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"

	cn "gno.land/r/gnoswap/v2/common"
	en "gno.land/r/gnoswap/v2/emission"
	"gno.land/r/gnoswap/v2/gns"
	pl "gno.land/r/gnoswap/v2/pool"
	pf "gno.land/r/gnoswap/v2/protocol_fee"
	rr "gno.land/r/gnoswap/v2/router"
	sr "gno.land/r/gnoswap/v2/staker"
)

func executeParameterChange(paramChange ParameterChangeInfo) {
	pkgPath := paramChange.PkgPath
	funcName := paramChange.Function
	paramsStr := paramChange.Params
	params := strings.Split(paramsStr, "*GOV*")

	switch pkgPath {

	case consts.EMISSION_PATH:
		switch funcName {
		case "ChangeDistributionPct":
			target01, pct01, target02, pct02, target03, pct03, target04, pct04 := handleEmissionChangeDistributionPct(params)
			en.ChangeDistributionPct(target01, pct01, target02, pct02, target03, pct03, target04, pct04)
		}

	case consts.GNS_PATH:
		switch funcName {
		case "SetAvgBlockTimeInMs":
			ms := handleGnsSetAvgBlockTimeInMs(params)
			gns.SetAvgBlockTimeInMs(ms)
		}

	case consts.GOV_GOVERNANCE_PATH:
		switch funcName {
		case "Reconfigure":
			votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow := handleGovernanceReconfigure(params)
			Reconfigure(votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow)
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
		case "GnsSetAvgBlockTimeInMs":
			ms := handleGnsSetAvgBlockTimeInMs(params)
			sr.GnsSetAvgBlockTimeInMs(ms)
		}

	case consts.COMMON_PATH:
		switch funcName {
		case "SetHalt":
			halt := handleSingleBool(params)
			cn.SetHalt(halt)
		}

	default:
		panic(ufmt.Sprintf("invalid package path(%s) and function name(%s)", pkgPath, funcName))
	}
}

func handleEmissionChangeDistributionPct(params []string) (
	int, uint64,
	int, uint64,
	int, uint64,
	int, uint64,
) {
	if len(params) != 8 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	target01 := strToInt(params[0])
	pct01 := parseUint(params[1], 10, 64)

	target02 := strToInt(params[2])
	pct02 := parseUint(params[3], 10, 64)

	target03 := strToInt(params[4])
	pct03 := parseUint(params[5], 10, 64)

	target04 := strToInt(params[6])
	pct04 := parseUint(params[7], 10, 64)

	return target01, pct01, target02, pct02, target03, pct03, target04, pct04
}

func handleGnsSetAvgBlockTimeInMs(params []string) int64 {
	if len(params) != 1 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	return int64(parseUint(params[0], 10, 64))
}

func handleGovernanceReconfigure(params []string) (
	uint64, uint64, uint64, uint64, uint64, uint64, uint64,
) {
	if len(params) != 7 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	votingStartDelay := parseUint(params[0], 10, 64)
	votingPeriod := parseUint(params[1], 10, 64)
	votingWeightSmoothingDuration := parseUint(params[2], 10, 64)
	quorum := parseUint(params[3], 10, 64)
	proposalCreationThreshold := parseUint(params[4], 10, 64)
	executionDelay := parseUint(params[5], 10, 64)
	executionWindow := parseUint(params[6], 10, 64)

	return votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow
}

func handlePoolSetFeeProtocol(params []string) (uint8, uint8) {
	if len(params) != 2 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	feeProtocol0 := parseUint(params[0], 10, 64)
	feeProtocol1 := parseUint(params[1], 10, 64)

	return uint8(feeProtocol0), uint8(feeProtocol1)
}

func handleSingleUint64(params []string) uint64 {
	if len(params) != 1 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	return parseUint(params[0], 10, 64)
}

func handlePoolPathTier(params []string) (string, uint64) {
	if len(params) != 2 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	return params[0], parseUint(params[1], 10, 64)
}

func handleTwoInt64(params []string) (int64, int64) {
	if len(params) != 2 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	return int64(parseUint(params[0], 10, 64)), int64(parseUint(params[1], 10, 64))
}

func handleSingleBool(params []string) bool {
	if len(params) != 1 {
		panic(ufmt.Sprintf("invalid params(%s)", params))
	}

	if params[0] == "true" {
		return true
	} else if params[0] == "false" {
		return false
	} else {
		panic(ufmt.Sprintf("invalid bool(%s)", params[0]))
	}
}
