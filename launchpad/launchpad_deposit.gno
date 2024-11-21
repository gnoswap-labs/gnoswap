package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"

	"gno.land/r/gnoswap/v1/gns"
	gs "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

var (
	// depositId -> deposit
	deposits = make(map[string]Deposit)

	// proejct -> tier -> []depositId
	depositsByProject = make(map[string]map[string][]string)

	// user -> []depositId
	depositsByUser = make(map[std.Address][]string)

	//  user -> project -> []depositId
	depositsByUserByProject = make(map[std.Address]map[string][]string)
)

// DepositGns deposit gns to the project's tier
// gns will be locked in `launchpad` contract
// xgns will be minted to the `launchpad` contract
// Returns depositId
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#depositgns
func DepositGns(
	targetProjectTierId string,
	amount uint64,
) string {
	projectId, tierStr := getProjectIdAndTierFromTierId(targetProjectTierId)
	project, exist := projects[projectId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("launchpad_deposit.gno__DepositGns() || projectTierId(%s) not found", targetProjectTierId),
		))
	}

	// check conditions (grc20 tokens balance)
	checkDepositConditions(project)

	// check if project is active
	if !checkProjectActive(project) {
		panic(addDetailToError(
			errInactiveProject,
			ufmt.Sprintf("launchpad_deposit.gno__DepositGns() || projectTierId(%s) > project is not active", targetProjectTierId),
		))
	}

	// check if tier is active
	tier := getTier(project, tierStr)
	if !checkTierActive(project, tier) {
		panic(addDetailToError(
			errInactiveTier,
			ufmt.Sprintf("launchpad_deposit.gno__DepositGns() || projectTierId(%s) > tier is not active", targetProjectTierId),
		))
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	// after all pre-checks
	calculateDepositReward()
	project = projects[projectId]    // get updates project
	tier = getTier(project, tierStr) // get updates tier

	// update gov_staker contract's variable to calculate proejct's recipient's reward
	gs.SetAmountByProjectWallet(project.recipient, amount, true) // true == add

	// gns will be locked in `launchpad` contract
	gns.TransferFrom(
		a2u(std.PrevRealm().Addr()),
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)

	// xgns will be minted to the `launchpad` contract
	xgns.Mint(
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)

	// deposit History
	depositor := std.PrevRealm().Addr()
	depositorStr := depositor.String()
	depositId := ufmt.Sprintf("%s:%s:%s:%d", projectId, tierStr, depositorStr, std.GetHeight())

	// calculate claimable height & time base on deposit height & time
	calcClaimableHeight := uint64(std.GetHeight()) + tier.collectWaitDuration
	_claimWaitDurationTimestamp := uint64(0)
	switch tierStr {
	case "30":
		_claimWaitDurationTimestamp = TIMESTAMP_3DAYS
	case "90":
		_claimWaitDurationTimestamp = TIMESTAMP_7DAYS
	case "180":
		_claimWaitDurationTimestamp = TIMESTAMP_14DAYS
	}
	calcClaimableTimestamp := uint64(time.Now().Unix()) + _claimWaitDurationTimestamp

	claimableHeight := min(calcClaimableHeight, tier.endHeight)
	claimableTime := min(calcClaimableTimestamp, tier.endTime)

	depositToHistory := Deposit{
		id:              depositId,
		projectId:       projectId,
		tier:            tierStr,
		depositor:       depositor,
		amount:          amount,
		depositHeight:   uint64(std.GetHeight()),
		depositTime:     uint64(time.Now().Unix()),
		claimableHeight: claimableHeight,
		claimableTime:   claimableTime,
	}

	// update deposits
	deposits[depositId] = depositToHistory

	// update depositsByUser
	depositsByUser[depositor] = append(depositsByUser[depositor], depositId)

	// update depositsByProject
	if _, exist := depositsByProject[projectId]; !exist {
		depositsByProject[projectId] = make(map[string][]string)
	}
	if _, exist := depositsByProject[projectId][tierStr]; !exist {
		depositsByProject[projectId][tierStr] = make([]string, 0)
	}
	depositsByProject[projectId][tierStr] = append(depositsByProject[projectId][tierStr], depositId)

	// update depositsByUserByProject
	if _, exist := depositsByUserByProject[depositor]; !exist {
		depositsByUserByProject[depositor] = make(map[string][]string)
	}
	if _, exist := depositsByUserByProject[depositor][projectId]; !exist {
		depositsByUserByProject[depositor][projectId] = make([]string, 0)
	}
	depositsByUserByProject[depositor][projectId] = append(depositsByUserByProject[depositor][projectId], depositId)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"DepositGns",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"targetProjectTierId", targetProjectTierId,
		"amount", ufmt.Sprintf("%d", amount),
		"internal_depositId", depositId,
		"internal_claimableHeight", ufmt.Sprintf("%d", claimableHeight),
		"internal_claimableTime", ufmt.Sprintf("%d", claimableTime),
	)

	// if first deposit
	if tier.totalParticipant == 0 {
		// update necessary data
		tier.startHeight = uint64(std.GetHeight())
		tier.startTime = uint64(time.Now().Unix())

		// calculate reward per block x96
		tierAmountPerBlockX96 := calcProjectTiersRewardPerBlockX96(tier)
		tier.tierAmountPerBlockX96 = tierAmountPerBlockX96

		// emit event
		std.Emit(
			"FirstDepoistForProjectTier",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"targetProjectTierId", targetProjectTierId,
			"amount", ufmt.Sprintf("%d", amount),
			"internal_depositId", depositId,
			"internal_claimableHeight", ufmt.Sprintf("%d", claimableHeight),
			"internal_claimableTime", ufmt.Sprintf("%d", claimableTime),
			"internal_tierAmountPerBlockX96", tierAmountPerBlockX96.ToString(),
		)
	}

	// update tier
	tier.totalDepositAmount += amount
	tier.actualDepositAmount += amount
	tier.totalParticipant += 1
	tier.actualParticipant += 1
	project = setTier(project, tierStr, tier)

	// update project
	project.totalDepositAmount += amount
	project.actualDepositAmount += amount
	project.totalParticipant += 1
	project.actualParticipant += 1
	projects[projectId] = project

	return depositId
}

// CollectDepositGns collect deposited gns
// gns will be transfered from the `launchpad` to caller
// launchpad's xgns will be burned.
// Returns collected gns amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#collectdepositgns
func CollectDepositGns() uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()

	calculateDepositReward()

	caller := std.PrevRealm().Addr()
	userDeposits := depositsByUser[caller]

	prevAddr, prevRealm := getPrev()

	gnsToUser := uint64(0)
	for _, depositId := range userDeposits {
		deposit := deposits[depositId]

		// check active
		project, exist := projects[deposit.projectId]
		if !exist {
			panic(addDetailToError(
				errDataNotFound,
				ufmt.Sprintf("launchpad_deposit.gno__CollectDepositGns() || depositId(%s) > projectId(%s) not found", depositId, deposit.projectId),
			))
		}

		tier := getTier(project, deposit.tier)
		if checkTierActive(project, tier) {
			continue
		}

		// collected
		if deposit.depositCollectHeight != 0 {
			continue
		}

		deposit.depositCollectHeight = uint64(std.GetHeight())
		deposit.depositCollectTime = uint64(time.Now().Unix())
		deposits[deposit.id] = deposit

		gnsToUser += deposit.amount

		// update gov_staker contract's variable to calculate proejct's recipient's reward
		gs.SetAmountByProjectWallet(project.recipient, deposit.amount, false) // subtract

		// update tier
		tier.actualDepositAmount -= deposit.amount
		tier.actualParticipant -= 1

		// update project
		project = setTier(project, deposit.tier, tier)
		project.actualDepositAmount -= deposit.amount
		project.actualParticipant -= 1
		projects[deposit.projectId] = project

		// emit event for each deposit
		std.Emit(
			"CollectDepositGns",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_depositId", depositId,
			"internal_amount", ufmt.Sprintf("%d", deposit.amount),
		)
	}

	if gnsToUser > 0 {
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), gnsToUser)
		gns.Transfer(a2u(caller), gnsToUser)

		return gnsToUser // return accumulated gns amount being withdrawn
	}

	return 0
}

// CollectDepositGnsByProjectId collect deposited gns of certain project by caller
// gns will be transfered from the `launchpad` to caller
// launchpad's xgns will be burned
// Returns collected gns amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#collectdepositgnsbyprojectid
func CollectDepositGnsByProjectId(projectId string) uint64 {
	_, exist := projects[projectId]
	if !exist {
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		return 0
	}

	depositIds, exist := depositsByUserByProject[caller][projectId]
	if !exist {
		return 0
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateDepositReward()

	prevAddr, prevRealm := getPrev()

	gnsToUser := uint64(0)
	for _, depositId := range depositIds {
		deposit := deposits[depositId]

		// check active
		project, exist := projects[deposit.projectId]
		if !exist {
			panic(addDetailToError(
				errDataNotFound,
				ufmt.Sprintf("launchpad_deposit.gno__CollectDepositGnsByProjectId() || depositId(%s) > projectId(%s) not found", depositId, deposit.projectId),
			))
		}

		tier := getTier(project, deposit.tier)
		if checkTierActive(project, tier) {
			continue
		}

		// collected
		if deposit.depositCollectHeight != 0 {
			continue
		}

		deposit.depositCollectHeight = uint64(std.GetHeight())
		deposit.depositCollectTime = uint64(time.Now().Unix())
		deposits[deposit.id] = deposit

		gnsToUser += deposit.amount

		// update gov_staker contract's variable to calculate proejct's recipient's reward
		gs.SetAmountByProjectWallet(project.recipient, deposit.amount, false) // subtract

		// update tier
		tier.actualDepositAmount -= deposit.amount
		tier.actualParticipant -= 1

		// update project
		project = setTier(project, deposit.tier, tier)
		project.actualDepositAmount -= deposit.amount
		project.actualParticipant -= 1
		projects[deposit.projectId] = project

		// emit event for each deposit
		std.Emit(
			"CollectDepositGnsByProjectId",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"projectId", projectId,
			"internal_depositId", depositId,
			"internal_amount", ufmt.Sprintf("%d", deposit.amount),
		)
	}

	if gnsToUser > 0 {
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), gnsToUser)
		gns.Transfer(a2u(caller), gnsToUser)

		return gnsToUser // return accumulated gns amount being withdrawn
	}

	return 0
}

// CollectDepositGnsByDepositId collect deposited gns of certain deposit
// gns will be transfered from the `launchpad` to caller
// launchpad's xgns will be burned
// Returns collected gns amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#collectdepositgnsbydepositid
func CollectDepositGnsByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		return 0
	}

	project, exist := projects[deposit.projectId]
	if !exist {
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		return 0
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateDepositReward()
	project = projects[deposit.projectId] // get updates project

	// check active
	tier := getTier(project, deposit.tier)
	if checkTierActive(project, tier) {
		return 0
	}

	// collected
	if deposit.depositCollectHeight != 0 {
		return 0
	}

	deposit.depositCollectHeight = uint64(std.GetHeight())
	deposit.depositCollectTime = uint64(time.Now().Unix())
	deposits[deposit.id] = deposit

	// update gov_staker contract's variable to calculate proejct's recipient's reward
	gs.SetAmountByProjectWallet(project.recipient, deposit.amount, false) // subtract

	// update tier
	tier.actualDepositAmount -= deposit.amount
	tier.actualParticipant -= 1

	// update project
	project = setTier(project, deposit.tier, tier)
	project.actualDepositAmount -= deposit.amount
	project.actualParticipant -= 1
	projects[deposit.projectId] = project

	// emit event for each deposit
	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CollectDepositGnsByDepositId",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"depositId", depositId,
		"internal_amount", ufmt.Sprintf("%d", deposit.amount),
	)

	if deposit.amount > 0 {
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), deposit.amount)
		gns.Transfer(a2u(caller), deposit.amount)

		return deposit.amount //
	}

	return 0
}

func getProjectIdFromTierId(tierId string) string {
	// input: gno.land/r/gnoswap/gns:123:30
	// output: gno.land/r/gnoswap/gns:123

	res, err := common.Split(tierId, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("launchpad_deposit.gno__getProjectIdFromTierId() || invalid tierId: %s", tierId),
		))
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1])
}

func getProjectIdAndTierFromTierId(tierId string) (string, string) {
	res, err := common.Split(tierId, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("launchpad_deposit.gno__getProjectIdAndTierFromTierId() || invalid tierId: %s", tierId),
		))
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1]), res[2]
}

func checkDepositConditions(project Project) {
	if project.conditions == nil {
		return
	}

	for _, condition := range project.conditions {
		if condition.minAmount == 0 {
			continue
		} else {
			// check balance
			var balance uint64
			if condition.tokenPath == consts.GOV_XGNS_PATH {
				balance = xgns.BalanceOf(a2u(std.PrevRealm().Addr()))
			} else {
				balance = balanceOfByRegisterCall(condition.tokenPath, std.PrevRealm().Addr())
			}
			if balance < condition.minAmount {
				panic(addDetailToError(
					errNotEnoughBalance,
					ufmt.Sprintf("launchpad_deposit.gno__checkDepositConditions() || insufficient balance(%d) for token(%s)", balance, condition.tokenPath),
				))
			}
		}
	}
}

func checkProjectActive(project Project) bool {
	if project.startHeight > uint64(std.GetHeight()) {
		// not started yet
		return false
	}

	if project.endHeight < uint64(std.GetHeight()) {
		// already ended
		return false
	}

	return true
}

func checkTierActive(project Project, tier Tier) bool {
	if tier.endHeight < uint64(std.GetHeight()) {
		return false
	}

	return true
}

func getTier(project Project, tierStr string) Tier {
	switch tierStr {
	case "30":
		return project.tier30
	case "90":
		return project.tier90
	case "180":
		return project.tier180
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("launchpad_deposit.gno__getTier() || invalid tierStr: %s", tierStr),
		))
	}
}

func setTier(project Project, tierStr string, tier Tier) Project {
	switch tierStr {
	case "30":
		project.tier30 = tier
	case "90":
		project.tier90 = tier
	case "180":
		project.tier180 = tier
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("launchpad_deposit.gno__setTier() || invalid tierStr: %s", tierStr),
		))
	}

	return project
}
