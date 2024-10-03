package launchpad

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"
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
	// only admin can create project
	if std.GetOrigCaller() != consts.GNOSWAP_ADMIN {
		panic("only admin can create project")
	}

	if _, exist := registered[tokenPath]; !exist {
		panic("token not registered")
	}

	if !(recipient.IsValid()) {
		panic("invalid recipient addr")
	}

	if strings.Contains(conditionsToken, "*PAD*") {
		tokensToCheck := strings.Split(conditionsToken, "*PAD*")
		for _, token := range tokensToCheck {
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

	if startTime < uint64(time.Now().Unix()) {
		panic("invalid start time, can not start project in past")
	}

	transferFromByRegisterCall(
		tokenPath,
		std.GetOrigCaller(),
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
	tier30AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier30Amount), q96)
	tier30AmountPerSecondX96 := new(u256.Uint).Div(tier30AmountX96, u256.NewUint(TIMESTAMP_30DAYS))
	tier30 := Tier{
		id:                     generateTierId(projectId, 30),
		collectWaitDuration:    TIMESTAMP_3DAYS,
		tierAmount:             tier30Amount,
		tierAmountPerSecondX96: tier30AmountPerSecondX96,
		endTime:                startTime + TIMESTAMP_30DAYS,
	}

	tier90AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier90Amount), q96)
	tier90AmountPerSecondX96 := new(u256.Uint).Div(tier90AmountX96, u256.NewUint(TIMESTAMP_90DAYS))
	tier90 := Tier{
		id:                     generateTierId(projectId, 90),
		collectWaitDuration:    TIMESTAMP_7DAYS,
		tierAmount:             tier90Amount,
		tierAmountPerSecondX96: tier90AmountPerSecondX96,
		endTime:                startTime + TIMESTAMP_90DAYS,
	}

	tier180AmountX96 := new(u256.Uint).Mul(u256.NewUint(tier180Amount), q96)
	tier180AmountPerSecondX96 := new(u256.Uint).Div(tier180AmountX96, u256.NewUint(TIMESTAMP_180DAYS))
	tier180 := Tier{
		id:                     generateTierId(projectId, 180),
		collectWaitDuration:    TIMESTAMP_14DAYS,
		tierAmount:             tier180Amount,
		tierAmountPerSecondX96: tier180AmountPerSecondX96,
		endTime:                startTime + TIMESTAMP_180DAYS,
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
		startTime:     startTime,
	}

	projects[projectId] = project

	std.Emit(
		"CreateProject",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_tokenPath", tokenPath,
		"p_recipient", recipient.String(),
		"p_depositAmount", ufmt.Sprintf("%d", depositAmount),
		"p_conditionsToken", conditionsToken,
		"p_conditionsAmount", conditionsAmount,
		"p_tier30Ratio", ufmt.Sprintf("%d", tier30Ratio),
		"p_tier90Ratio", ufmt.Sprintf("%d", tier90Ratio),
		"p_tier180Ratio", ufmt.Sprintf("%d", tier180Ratio),
		"p_startTime", ufmt.Sprintf("%d", startTime),
		"projectId", projectId,
		"tier30Amount", ufmt.Sprintf("%d", tier30Amount),
		"tier90Amount", ufmt.Sprintf("%d", tier90Amount),
		"tier180Amount", ufmt.Sprintf("%d", tier180Amount),
	)

	return projectId
}

// RefundProject refunds project's left token amount
// - only recipient can refund
//
// returns amount
func RefundProject(projectId string) uint64 {
	caller := std.GetOrigCaller()
	project, exist := projects[projectId]
	if !exist {
		panic("project not exist")
	}

	recipient := project.recipient
	if caller != recipient {
		panic("only recipient can refund")
	}

	endTime := project.startTime + TIMESTAMP_180DAYS // 180 is max pool duration
	height := uint64(std.GetHeight())
	now := uint64(time.Now().Unix())

	if endTime > now {
		panic("project not ended yet")
	}

	toRefund := project.depositAmount - project.totalCollectedAmount
	if toRefund > 0 {
		transferByRegisterCall(
			project.tokenPath,
			recipient,
			toRefund,
		)

		std.Emit(
			"RefundProject",
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"p_projectId", projectId,
			"recipient", recipient.String(),
			"toRefund", ufmt.Sprintf("%d", toRefund),
		)
	}

	return toRefund
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
