package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"

	"gno.land/r/gnoswap/v2/gns"
)

var (
	projects = make(map[string]Project) // projectId -> project

	// project tier should distrubte project token if deposit ever happend
	// therefore we need to keep track of project tiers without deposit
	projectTiersWithoutDeposit = make(map[string]bool) // tierId -> true
)

var (
	q96 = u256.Zero()
)

func init() {
	q96 = u256.MustFromDecimal(consts.Q96)
}

// CreateProject creates a new project
// - only admin can create project
//
// returns projectId
func CreateProject(
	name string,
	tokenPath string,
	recipient std.Address,
	depositAmount uint64,
	conditionsToken string, // SEP BY *PAD*
	conditionsAmount string, // SEP BY *PAD*
	tier30Ratio uint64, // 10 => 10%
	tier90Ratio uint64, // 20
	tier180Ratio uint64, // 70
	startTime uint64,
) string { // projectId
	assertUserCall()

	// only admin can create project
	if std.PrevRealm().Addr() != consts.ADMIN {
		panic("only admin can create project")
	}

	if _, exist := registered[tokenPath]; !exist {
		panic("token not registered")
	}

	if !(recipient.IsValid()) {
		panic("invalid recipient addr")
	}

	if depositAmount == 0 {
		panic("can not deposit 0")
	}

	if strings.Contains(conditionsToken, "*PAD*") {
		tokensToCheck := strings.Split(conditionsToken, "*PAD*")
		for _, token := range tokensToCheck {
			if token == consts.GOV_XGNS_PATH {
				continue
			}
			if _, exist := registered[token]; !exist {
				panic(ufmt.Sprintf("condition token(%s) not registered", token))
			}
		}
	}

	projectId := generateProjectId(tokenPath)
	_, exist := projects[projectId]
	if exist {
		panic("project already exist")
	}

	if tier30Ratio+tier90Ratio+tier180Ratio != 100 {
		panic("invalid ratio, sum of all tiers should be 100")
	}

	if startTime <= uint64(time.Now().Unix()) {
		panic("invalid start time, can not start project in past")
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	transferFromByRegisterCall(
		tokenPath,
		std.PrevRealm().Addr(),
		std.Address(consts.LAUNCHPAD_ADDR),
		depositAmount,
	)

	tier30Amount := depositAmount * tier30Ratio / 100
	tier90Amount := depositAmount * tier90Ratio / 100
	tier180Amount := depositAmount * tier180Ratio / 100
	sumAll := tier30Amount + tier90Amount + tier180Amount
	left := depositAmount - sumAll
	if left > 0 {
		// uAmounts can be left due to rounding
		// XXX: how to handle this?
		// tier180Amount += left
	}
	createdHeight := uint64(std.GetHeight())
	createdTime := uint64(time.Now().Unix())

	// check grc20 required conditions
	conditions := makeConditions(conditionsToken, conditionsAmount)

	// create tier
	avgBlockTimeMs := uint64(gns.GetAvgBlockTimeInMs())

	height := uint64(std.GetHeight())
	now := uint64(time.Now().Unix())

	timeUntilStart := startTime - now
	blockDuration := timeUntilStart * 1000 / avgBlockTimeMs
	startHeight := height + blockDuration

	tier30EndHeight := startHeight + (TIMESTAMP_30DAYS * 1000 / avgBlockTimeMs)
	tier30Id := generateTierId(projectId, 30)
	tier30 := Tier{
		id:                  tier30Id,
		collectWaitDuration: TIMESTAMP_3DAYS * 1000 / avgBlockTimeMs,
		tierAmount:          tier30Amount,
		endHeight:           tier30EndHeight,
		endTime:             startTime + TIMESTAMP_30DAYS,
	}
	projectTiersWithoutDeposit[tier30Id] = true

	tier90EndHeight := startHeight + (TIMESTAMP_90DAYS * 1000 / avgBlockTimeMs)
	tier90Id := generateTierId(projectId, 90)
	tier90 := Tier{
		id:                  tier90Id,
		collectWaitDuration: TIMESTAMP_7DAYS * 1000 / avgBlockTimeMs,
		tierAmount:          tier90Amount,
		endHeight:           tier90EndHeight,
		endTime:             startTime + TIMESTAMP_90DAYS,
	}
	projectTiersWithoutDeposit[tier90Id] = true

	tier180EndHeight := startHeight + (TIMESTAMP_180DAYS * 1000 / avgBlockTimeMs)
	tier180Id := generateTierId(projectId, 180)
	tier180 := Tier{
		id:                  tier180Id,
		collectWaitDuration: TIMESTAMP_14DAYS * 1000 / avgBlockTimeMs,
		tierAmount:          tier180Amount,
		endHeight:           tier180EndHeight,
		endTime:             startTime + TIMESTAMP_180DAYS,
	}
	projectTiersWithoutDeposit[tier180Id] = true

	// create project
	project := Project{
		id:            projectId,
		name:          name,
		tokenPath:     tokenPath,
		depositAmount: depositAmount,
		recipient:     recipient,
		conditions:    conditions,
		tier30Ratio:   tier30Ratio,
		tier30:        tier30,
		tier90:        tier90,
		tier90Ratio:   tier90Ratio,
		tier180:       tier180,
		tier180Ratio:  tier180Ratio,
		createdHeight: createdHeight,
		createdTime:   createdTime,
		startHeight:   startHeight,
		startTime:     startTime,
		endHeight:     tier180.endHeight,
		endTime:       tier180.endTime,
	}

	projects[projectId] = project

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"CreateProject",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"name", name,
		"tokenPath", tokenPath,
		"recipient", recipient.String(),
		"depositAmount", ufmt.Sprintf("%d", depositAmount),
		"conditionsToken", conditionsToken,
		"conditionsAmount", conditionsAmount,
		"tier30Ratio", ufmt.Sprintf("%d", tier30Ratio),
		"tier90Ratio", ufmt.Sprintf("%d", tier90Ratio),
		"tier180Ratio", ufmt.Sprintf("%d", tier180Ratio),
		"startTime", ufmt.Sprintf("%d", startTime),
		"internal_startHeight", ufmt.Sprintf("%d", startHeight),
		"internal_projectId", projectId,
		"internal_tier30Amount", ufmt.Sprintf("%d", tier30Amount),
		"internal_tier30EndHeight", ufmt.Sprintf("%d", tier30EndHeight),
		"internal_tier90Amount", ufmt.Sprintf("%d", tier90Amount),
		"internal_tier90EndHeight", ufmt.Sprintf("%d", tier90EndHeight),
		"internal_tier180Amount", ufmt.Sprintf("%d", tier180Amount),
		"internal_tier180EndHeight", ufmt.Sprintf("%d", tier180EndHeight),
	)

	return projectId
}

func TransferLeftFromProjectByAdmin(projectId string, recipient std.Address) uint64 {
	assertUserCall()
	caller := std.PrevRealm().Addr()
	if caller != consts.ADMIN {
		panic("only admin can transfer left from project")
	}

	project, exist := projects[projectId]
	if !exist {
		panic("project not found")
	}

	if !recipient.IsValid() {
		panic("invalid recipient addr")
	}

	height := uint64(std.GetHeight())
	if height < project.endHeight {
		panic("project not ended yet")
	}

	if project.refundedHeight != 0 {
		panic("project already refunded")
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateDepositReward()
	project = projects[projectId] // get updates project

	// calculate left reward
	tier30Full := project.tier30.tierAmount
	tier90Full := project.tier90.tierAmount
	tier180Full := project.tier180.tierAmount

	left30 := tier30Full - project.tier30.calculatedAmount
	left90 := tier90Full - project.tier90.calculatedAmount
	left180 := tier180Full - project.tier180.calculatedAmount
	leftReward := left30 + left90 + left180

	if leftReward > 0 {
		transferByRegisterCall(
			project.tokenPath,
			recipient,
			leftReward,
		)
	}

	std.Emit(
		"TransferLeftFromProjectByAdmin",
		"projectId", projectId,
		"recipient", recipient.String(),
		"internal_tokenPath", project.tokenPath,
		"internal_leftReward", ufmt.Sprintf("%d", leftReward),
		"internal_tier30Full", ufmt.Sprintf("%d", tier30Full),
		"internal_tier30Left", ufmt.Sprintf("%d", left30),
		"internal_tier90Full", ufmt.Sprintf("%d", tier90Full),
		"internal_tier90Left", ufmt.Sprintf("%d", left90),
		"internal_tier180Full", ufmt.Sprintf("%d", tier180Full),
		"internal_tier180Left", ufmt.Sprintf("%d", left180),
	)

	project.refundedAmount = leftReward
	project.refundedHeight = height
	project.refundedTime = uint64(time.Now().Unix())
	projects[projectId] = project

	return leftReward
}

func generateProjectId(tokenPath string) string {
	// gno.land/r/gnoswap/gns:123
	return ufmt.Sprintf("%s:%d", tokenPath, std.GetHeight())
}

func generateTierId(projectId string, duration uint64) string {
	// gno.land/r/gnoswap/gns:123:30
	return ufmt.Sprintf("%s:%d", projectId, duration)
}

func makeConditions(conditionsToken string, conditionsAmount string) map[string]Condition {
	if conditionsToken == "" || conditionsAmount == "" {
		return nil
	}

	conditions := make(map[string]Condition)
	tokens := strings.Split(conditionsToken, "*PAD*")
	amounts := strings.Split(conditionsAmount, "*PAD*")
	if len(tokens) != len(amounts) {
		panic(ufmt.Sprintf("invalid conditions(numTokens(%d) != numAmounts(%d))", len(tokens), len(amounts)))
	}

	for i, token := range tokens {
		conditions[token] = Condition{
			tokenPath: token,
			minAmount: parseUint(amounts[i], 10, 64),
		}
	}
	return conditions
}
