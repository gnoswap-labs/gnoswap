package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
)

var (
	projects = make(map[string]Project)
)

var (
	q96 = u256.Zero()
)

func init() {
	println("main_init")
	q96 = u256.MustFromDecimal(consts.Q96)
}

// CreateProject creates a new project
// - only admin can create project
//
// returns projectId
func CreateProject(
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

	avgBlockTimeMs := uint64(gns.GetAvgBlockTimeInMs())

	height := uint64(std.GetHeight())
	now := uint64(time.Now().Unix())

	timeUntilStart := startTime - now
	blockDuration := timeUntilStart * 1000 / avgBlockTimeMs
	startHeight := height + blockDuration

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
	tier30EndHeight := startHeight + (TIMESTAMP_30DAYS * 1000 / avgBlockTimeMs)
	tier30AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier30Amount), q96)
	tier30AmountPerBlockX96 := new(u256.Uint).Div(tier30AmountX96, u256.NewUint(tier30EndHeight-startHeight))
	tier30 := Tier{
		id:                    generateTierId(projectId, 30),
		collectWaitDuration:   TIMESTAMP_3DAYS * 1000 / avgBlockTimeMs,
		tierAmount:            tier30Amount,
		tierAmountPerBlockX96: tier30AmountPerBlockX96,
		endHeight:             tier30EndHeight,
		endTime:               startTime + TIMESTAMP_30DAYS,
	}

	tier90EndHeight := startHeight + (TIMESTAMP_90DAYS * 1000 / avgBlockTimeMs)
	tier90AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier90Amount), q96)
	tier90AmountPerBlockX96 := new(u256.Uint).Div(tier90AmountX96, u256.NewUint(tier90EndHeight-startHeight))
	tier90 := Tier{
		id:                    generateTierId(projectId, 90),
		collectWaitDuration:   TIMESTAMP_7DAYS * 1000 / avgBlockTimeMs,
		tierAmount:            tier90Amount,
		tierAmountPerBlockX96: tier90AmountPerBlockX96,
		endHeight:             tier90EndHeight,
		endTime:               startTime + TIMESTAMP_90DAYS,
	}

	tier180EndHeight := startHeight + (TIMESTAMP_180DAYS * 1000 / avgBlockTimeMs)
	tier180AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier180Amount), q96)
	tier180AmountPerBlockX96 := new(u256.Uint).Div(tier180AmountX96, u256.NewUint(tier180EndHeight-startHeight))
	tier180 := Tier{
		id:                    generateTierId(projectId, 180),
		collectWaitDuration:   TIMESTAMP_14DAYS * 1000 / avgBlockTimeMs,
		tierAmount:            tier180Amount,
		tierAmountPerBlockX96: tier180AmountPerBlockX96,
		endHeight:             tier180EndHeight,
		endTime:               startTime + TIMESTAMP_180DAYS,
	}

	// create project
	project := Project{
		id:            projectId,
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
		"internal_tier30AmountPerBlockX96", tier30AmountPerBlockX96.ToString(),
		"internal_tier90Amount", ufmt.Sprintf("%d", tier90Amount),
		"internal_tier90EndHeight", ufmt.Sprintf("%d", tier90EndHeight),
		"internal_tier90AmountPerBlockX96", tier90AmountPerBlockX96.ToString(),
		"internal_tier180Amount", ufmt.Sprintf("%d", tier180Amount),
		"internal_tier180EndHeight", ufmt.Sprintf("%d", tier180EndHeight),
		"internal_tier180AmountPerBlockX96", tier180AmountPerBlockX96.ToString(),
	)

	return projectId
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
