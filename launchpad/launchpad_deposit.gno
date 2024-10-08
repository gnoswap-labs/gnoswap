package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
	gs "gno.land/r/gnoswap/v2/gov/staker"
	"gno.land/r/gnoswap/v2/gov/xgns"
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
// - gns will be locked in `launchpad` contract
// - xgns will be minted to the `launchpad` contract
//
// returns depositId
func DepositGns(
	targetProjectTierId string,
	amount uint64,
) string {
	projectId, tierStr := getProjectIdAndTierFromTierId(targetProjectTierId)
	project, exist := projects[projectId]
	if !exist {
		panic(ufmt.Sprintf("project not found: %s", projectId))
	}

	// check conditions (grc20 tokens balance)
	checkDepositConditions(project)

	// check if project is active
	if !checkProjectActive(project) {
		panic(ufmt.Sprintf("project is not active: %s", projectId))
	}

	// check if tier is active
	tier := getTier(project, tierStr)
	if !checkTierActive(project, tier) {
		panic(ufmt.Sprintf("tier is not active: %s", tierStr))
	}

	// after all pre-checks
	calculateDepositReward()

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

	// update gov_staker contract's variable to calculate proejct's recipient's reward
	gs.SetAmountByProjectWallet(project.recipient, amount, true) // true == add

	// update tier
	tier.depositAmount += amount
	tier.participant += 1
	project = setTier(project, tierStr, tier)

	// update project
	project.totalDepositAmount += amount
	project.actualDepositAmount += amount
	project.totalParticipant += 1
	project.actualParticipant += 1
	projects[projectId] = project

	// deposit History
	depositor := std.PrevRealm().Addr()
	depositorStr := depositor.String()
	depositId := projectId + ":" + tierStr + ":" + depositorStr + ":" + ufmt.Sprintf("%d", std.GetHeight())
	depositToHistory := Deposit{
		id:            depositId,
		projectId:     projectId,
		tier:          tierStr,
		depositor:     depositor,
		amount:        amount,
		depositHeight: uint64(std.GetHeight()),
		depositTime:   uint64(time.Now().Unix()),
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

	std.Emit(
		"DepositGns",
		"m_prevRealm", prevRealm(),
		"p_targetProjectTierId", targetProjectTierId,
		"p_amount", ufmt.Sprintf("%d", amount),
		"depositId", depositId,
	)

	return depositId
}

// CollectDepositGns collect deposited gns
// - gns will be transfered from the `launchpad` to caller
// - launchpad's xgns will be burned
//
// returns collected gns amount
func CollectDepositGns() uint64 {
	calculateDepositReward()

	caller := std.PrevRealm().Addr()
	userDeposits := depositsByUser[caller]

	gnsToUser := uint64(0)
	for _, depositId := range userDeposits {
		deposit := deposits[depositId]

		// check active
		project, exist := projects[deposit.projectId]
		if !exist {
			panic(ufmt.Sprintf("SHOULD_NOT_HAPPEN__project not found: %s", deposit.projectId))
		}

		tier := getTier(project, deposit.tier)
		if checkTierActive(project, tier) {
			println("CollectDepositGns()_STILL ACTIVE TIER", deposit.tier)
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
		tier.depositAmount -= deposit.amount
		tier.participant -= 1

		// update project
		project = setTier(project, deposit.tier, tier)
		project.actualDepositAmount -= deposit.amount
		project.actualParticipant -= 1
		projects[deposit.projectId] = project

		// emit event for each deposit
		std.Emit(
			"CollectDepositGns",
			"m_prevRealm", prevRealm(),
			"depositId", depositId,
			"amount", ufmt.Sprintf("%d", deposit.amount),
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
// - gns will be transfered from the `launchpad` to caller
// - launchpad's xgns will be burned
//
// returns collected gns amount
func CollectDepositGnsByProjectId(projectId string) uint64 {
	project, exist := projects[projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", projectId)
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		println("NO DEPOSIT FOR THIS USER", caller)
		return 0
	}

	depositIds, exist := depositsByUserByProject[caller][projectId]
	if !exist {
		println("NO DEPOSIT FOR THIS PROJECT", projectId, " FOR UESR", caller)
		return 0
	}

	calculateDepositReward()

	gnsToUser := uint64(0)
	for _, depositId := range depositIds {
		deposit := deposits[depositId]

		// check active
		project, exist := projects[deposit.projectId]
		if !exist {
			panic(ufmt.Sprintf("SHOULD_NOT_HAPPEN__project not found: %s", deposit.projectId))
		}

		tier := getTier(project, deposit.tier)
		if checkTierActive(project, tier) {
			println("CollectDepositGns()_STILL ACTIVE TIER", deposit.tier)
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
		tier.depositAmount -= deposit.amount
		tier.participant -= 1

		// update project
		project = setTier(project, deposit.tier, tier)
		project.actualDepositAmount -= deposit.amount
		project.actualParticipant -= 1
		projects[deposit.projectId] = project

		// emit event for each deposit
		std.Emit(
			"CollectDepositGns",
			"m_prevRealm", prevRealm(),
			"depositId", depositId,
			"amount", ufmt.Sprintf("%d", deposit.amount),
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
// - gns will be transfered from the `launchpad` to caller
// - launchpad's xgns will be burned
//
// returns collected gns amount
func CollectDepositGnsByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		println("DEPOSIT NOT FOUND", depositId)
		return 0
	}

	project, exist := projects[deposit.projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", deposit.projectId)
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		println("NO DEPOSIT FOR THIS USER", caller)
		return 0
	}

	calculateDepositReward()

	// check active
	tier := getTier(project, deposit.tier)
	if checkTierActive(project, tier) {
		println("CollectDepositGns()_STILL ACTIVE TIER", deposit.tier)
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
	tier.depositAmount -= deposit.amount
	tier.participant -= 1

	// update project
	project = setTier(project, deposit.tier, tier)
	project.actualDepositAmount -= deposit.amount
	project.actualParticipant -= 1
	projects[deposit.projectId] = project

	// emit event for each deposit
	std.Emit(
		"CollectDepositGns",
		"m_prevRealm", prevRealm(),
		"depositId", depositId,
		"amount", ufmt.Sprintf("%d", deposit.amount),
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

	result := strings.Split(tierId, ":")
	if len(result) == 3 {
		return result[0] + ":" + result[1]
	}

	panic(ufmt.Sprintf("invalid tierId: %s", tierId))
}

func getProjectIdAndTierFromTierId(tierId string) (string, string) {
	result := strings.Split(tierId, ":")
	if len(result) == 3 {
		return result[0] + ":" + result[1], result[2]
	}

	panic(ufmt.Sprintf("invalid tierId: %s", tierId))
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
			balance := balanceOfByRegisterCall(condition.tokenPath, std.PrevRealm().Addr())
			if balance < condition.minAmount {
				panic(ufmt.Sprintf("insufficient balance(%d) for token(%s)", balance, condition.tokenPath))
			}
		}
	}
}

func checkProjectActive(project Project) bool {
	if project.startHeight > uint64(std.GetHeight()) {
		// not started yet
		println(ufmt.Sprintf("checkProjectActive()__project not started yet // startHeight: %d // now: %d", project.startHeight, uint64(std.GetHeight())))
		return false
	}

	if project.endHeight < uint64(std.GetHeight()) {
		// already ended
		println(ufmt.Sprintf("checkProjectActive()__project already ended // endHeight: %d // now: %d", project.endHeight, uint64(std.GetHeight())))
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
		panic(ufmt.Sprintf("getTier()__invalid tierStr: %s", tierStr))
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
		panic(ufmt.Sprintf("setTier()__invalid tierStr: %s", tierStr))
	}

	return project
}
