package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"
)

var (
	// depositId -> deposit
	deposits = make(map[string]Deposit)

	// proejct -> tier -> []depositId
	depositsByProject = make(map[string]map[string][]string)

	// user -> []depositId
	depositsByUser = make(map[string][]string)
)

func DepositGns(
	targetProjectTierId string,
	amount uint64,
) {
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

	// gns will be locked in `launchpad` contract
	gns.TransferFrom(
		a2u(std.GetOrigCaller()),
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)

	// xgns will be minted to the `launchpad` contract
	xgns.Mint(
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)

	// update tier
	tier.depositAmount += amount
	tier.participant += 1
	project = setTier(project, tierStr, tier)

	// update project
	project.totalDepositAmount += amount
	project.totalParticipant += 1
	projects[projectId] = project

	// deposit History
	depositor := std.GetOrigCaller()
	depositorStr := depositor.String()
	depositId := projectId + ":" + tierStr + ":" + depositorStr + ":" + ufmt.Sprintf("%d", std.GetHeight())
	depositToHistory := Deposit{
		id:            depositId,
		projectId:     projectId,
		tier:          tierStr,
		depositor:     depositor,
		amount:        amount,
		depositHeight: uint64(std.GetHeight()),
		depositAt:     uint64(time.Now().Unix()),
	}

	// update deposits
	deposits[depositId] = depositToHistory

	// update depositsByProject
	if _, exist := depositsByProject[projectId]; !exist {
		depositsByProject[projectId] = make(map[string][]string)
	}
	if _, exist := depositsByProject[projectId][tierStr]; !exist {
		depositsByProject[projectId][tierStr] = make([]string, 0)
	}
	depositsByProject[projectId][tierStr] = append(depositsByProject[projectId][tierStr], depositId)

	// update depositsByUser
	depositsByUser[depositorStr] = append(depositsByUser[depositorStr], depositId)

	// XXX: emit event
}

func ClaimDepositGns() uint64 {
	calculateDepositReward() // uncomment this line if L#149 `ClaimReward` is removed

	caller := std.GetOrigCaller()
	callerStr := caller.String()
	userDeposits := depositsByUser[callerStr]

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
			println("ClaimDepositGns_STILL ACTIVE TIER")
			continue
		}

		// claimed
		if deposit.depositClaimHeight != 0 {
			continue
		}

		deposit.depositClaimHeight = uint64(std.GetHeight())
		deposit.depositClaimAt = uint64(time.Now().Unix())
		deposits[deposit.id] = deposit

		gnsToUser += deposit.amount

		// update tier
		tier.depositAmount -= deposit.amount
		tier.participant -= 1
		project = setTier(project, deposit.tier, tier)
	}

	if gnsToUser > 0 {
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), gnsToUser)
		gns.Transfer(a2u(caller), gnsToUser)

		// umcomment L#110 `calculateDepositReward()`
		// ClaimReward()

		// XXX: emit event
		return gnsToUser
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
	for _, condition := range project.conditions {
		if condition.minAmount == 0 {
			continue
		} else {
			// check balance
			balance := balanceOfByRegisterCall(condition.tokenPath, std.GetOrigCaller())
			if balance < condition.minAmount {
				panic(ufmt.Sprintf("insufficient balance(%d) for token(%s)", balance, condition.tokenPath))
			}
		}
	}
}

func checkProjectActive(project Project) bool {
	if project.startTime > uint64(time.Now().Unix()) {
		// not started yet
		println(ufmt.Sprintf("checkProjectActive()__project not started yet // startTime: %d // now: %d", project.startTime, uint64(time.Now().Unix())))
		return false
	}

	if project.startTime+TIMESTAMP_180DAYS < uint64(time.Now().Unix()) {
		// already ended
		println(ufmt.Sprintf("checkProjectActive()__project already ended // endTime: %d // now: %d", project.startTime+TIMESTAMP_180DAYS, uint64(time.Now().Unix())))
		return false
	}

	return true
}

func checkTierActive(project Project, tier Tier) bool {
	if tier.endTime < uint64(time.Now().Unix()) {
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
