package governance

import (
	"std"
	"strings"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/gns"

	cn "gno.land/r/gnoswap/v2/common"
	cp "gno.land/r/gnoswap/v2/community_pool"
	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"
	pf "gno.land/r/gnoswap/v2/protocol_fee"
	rr "gno.land/r/gnoswap/v2/router"
	sr "gno.land/r/gnoswap/v2/staker"
)

func callableMsg(pkgPath, function, params string) bool {
	println(">> callableMsg", pkgPath, function, params)

	param := strings.Split(params, ",")

	switch pkgPath {

	case consts.EMISSION_PATH:
		switch function {
		case "ChangeDistributionPct":
			if len(param) != 8 {
				panic(ufmt.Sprintf("len(param) should be 8 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.GNS_PATH:
		switch function {
		case "SetAvgBlockTimeInMs":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.GOV_GOVERNANCE_PATH:
		switch function {
		case "Reconfigure":
			if len(param) != 7 {
				panic(ufmt.Sprintf("len(param) should be 7 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.POOL_PATH:
		switch function {
		case "SetFeeProtocol":
			if len(param) != 2 {
				panic(ufmt.Sprintf("len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "SetPoolCreationFee":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "SetWithdrawalFee":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.PROTOCOL_FEE_PATH:
		switch function {
		case "SetDevOpsPct":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.ROUTER_PATH:
		switch function {
		case "SetSwapFee":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.STAKER_PATH:
		switch function {
		case "SetDepositGnsAmount":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "SetPoolTier":
			if len(param) != 2 {
				panic(ufmt.Sprintf("len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "ChangePoolTier":
			if len(param) != 2 {
				panic(ufmt.Sprintf("len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "RemovePoolTier":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "SetUnstakingFee":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "SetWarmUp":
			if len(param) != 2 {
				panic(ufmt.Sprintf("len(param) should be 2 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		case "GnsSetAvgBlockTimeInMs":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true

		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.COMMON_PATH:
		switch function {
		case "SetHalt":
			if len(param) != 1 {
				panic(ufmt.Sprintf("len(param) should be 1 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	case consts.COMMUNITY_POOL_PATH:
		switch function {
		case "TransferToken":
			if len(param) != 3 {
				panic(ufmt.Sprintf("len(param) should be 3 but got %d, for param %s (pkgPath %s and function %s)", len(param), params, pkgPath, function))
			}
			return true
		default:
			panic(ufmt.Sprintf("invalid function %s for pkgPath %s", function, pkgPath))
		}

	default:
		panic(ufmt.Sprintf("invalid pkgPath(%s)", pkgPath))
	}
}

func executeParameterChange(msgs []string) {
	for _, msg := range msgs {
		splitExe := strings.Split(msg, "*EXE*")
		if len(splitExe) != 3 {
			panic(ufmt.Sprintf("invalid execution(%s) to split by *EXE*, seems like param didn't passed", msg))
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
}

func handleCommunityPoolTransferToken(params []string) (string, std.Address, uint64) {

	return params[0], std.Address(params[1]), parseUint(params[2], 10, 64)
}

func handleEmissionChangeDistributionPct(params []string) (
	int, uint64,
	int, uint64,
	int, uint64,
	int, uint64,
) {
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
	return int64(parseUint(params[0], 10, 64))
}

func handleGovernanceReconfigure(params []string) (
	uint64, uint64, uint64, uint64, uint64, uint64, uint64,
) {
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
	feeProtocol0 := parseUint(params[0], 10, 64)
	feeProtocol1 := parseUint(params[1], 10, 64)

	return uint8(feeProtocol0), uint8(feeProtocol1)
}

func handleSingleUint64(params []string) uint64 {
	return parseUint(params[0], 10, 64)
}

func handlePoolPathTier(params []string) (string, uint64) {
	return params[0], parseUint(params[1], 10, 64)
}

func handleTwoInt64(params []string) (int64, int64) {
	return int64(parseUint(params[0], 10, 64)), int64(parseUint(params[1], 10, 64))
}

func handleSingleBool(params []string) bool {
	switch params[0] {
	case "true":
		return true
	case "false":
		return false
	default:
		panic(ufmt.Sprintf("invalid bool(%s)", params[0]))
	}
}
