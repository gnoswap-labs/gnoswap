package dca_order

import (
	"strconv"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
	"gno.land/p/onbloc/json/v0"

	dca "gno.land/r/gnoswap/test/dca_order"
	"gno.land/r/gnoswap/halt/v1"
)

// GetOrderJSON returns the order as JSON, or "" when it does not exist.
// 64-bit integers are encoded as strings to survive float64 JSON parsers.
func (d *dcaOrderV1) GetOrderJSON(orderID uint64) string {
	order := d.getOrder(orderID)
	if order == nil {
		return ""
	}

	group := d.mustGetGroup(order.GroupID())

	claimable := u256.Zero()
	if order.IsActive() {
		endAcc, _ := settlementAcc(order, group)
		claimable = owedOutputU256(order.AmountPerExecution(), endAcc, order.AccDebtX128())
	}

	return marshal(map[string]*json.Node{
		"id":                 uintNode(order.ID()),
		"owner":              json.StringNode("", order.Owner().String()),
		"groupId":            json.StringNode("", order.GroupID()),
		"poolPath":           json.StringNode("", group.PoolPath()),
		"tokenIn":            json.StringNode("", group.TokenIn()),
		"tokenOut":           json.StringNode("", group.TokenOut()),
		"zeroForOne":         json.BoolNode("", group.ZeroForOne()),
		"interval":           intNode(group.Interval()),
		"amountPerExecution": intNode(order.AmountPerExecution()),
		"totalExecutions":    intNode(order.TotalExecutions()),
		"executedRounds":     uintNode(executedRounds(order, group)),
		"startRound":         uintNode(order.StartRound()),
		"endRound":           uintNode(order.EndRound()),
		"cancelRound":        uintNode(order.CancelRound()),
		"accDebtX128":        json.StringNode("", order.AccDebtX128().ToString()),
		"claimedOut":         json.StringNode("", order.ClaimedOut().ToString()),
		"claimable":          json.StringNode("", claimable.ToString()),
		"refundedIn":         intNode(order.RefundedIn()),
		"feePaid":            intNode(order.FeePaid()),
		"status":             json.StringNode("", order.Status().String()),
		"createdAt":          intNode(order.CreatedAt()),
		"createdAtHeight":    intNode(order.CreatedAtHeight()),
		"finalizedAt":        intNode(order.FinalizedAt()),
	})
}

// GetGroupJSON returns the group as JSON, or "" when it does not exist.
func (d *dcaOrderV1) GetGroupJSON(groupID string) string {
	group := d.getGroup(groupID)
	if group == nil {
		return ""
	}

	return marshal(map[string]*json.Node{
		"id":              json.StringNode("", group.ID()),
		"poolPath":        json.StringNode("", group.PoolPath()),
		"tokenIn":         json.StringNode("", group.TokenIn()),
		"tokenOut":        json.StringNode("", group.TokenOut()),
		"zeroForOne":      json.BoolNode("", group.ZeroForOne()),
		"interval":        intNode(group.Interval()),
		"round":           uintNode(group.Round()),
		"rate":            intNode(group.Rate()),
		"accX128":         json.StringNode("", group.AccX128().ToString()),
		"nextExecutionAt": intNode(group.NextExecutionAt()),
		"lastExecutedAt":  intNode(group.LastExecutedAt()),
		"activeOrders":    intNode(group.ActiveOrders()),
		"totalAmountIn":   json.StringNode("", group.TotalAmountIn().ToString()),
		"totalAmountOut":  json.StringNode("", group.TotalAmountOut().ToString()),
		"executable":      json.BoolNode("", isExecutable(group, time.Now().Unix())),
	})
}

// GetConfigJSON returns the configuration as JSON.
func (d *dcaOrderV1) GetConfigJSON() string {
	config := d.store.GetConfig()

	intervals := make([]*json.Node, 0, len(allowedIntervals))
	for _, interval := range allowedIntervals {
		intervals = append(intervals, intNode(interval))
	}

	return marshal(map[string]*json.Node{
		"creationFeeBps":        intNode(config.CreationFeeBps()),
		"minAmountPerExecution": intNode(config.MinAmountPerExecution()),
		"maxTotalExecutions":    intNode(config.MaxTotalExecutions()),
		"allowedIntervals":      json.ArrayNode("", intervals),
	})
}

// GetClaimable returns the output currently claimable by an active order.
func (d *dcaOrderV1) GetClaimable(orderID uint64) int64 {
	order := d.getOrder(orderID)
	if order == nil || !order.IsActive() {
		return 0
	}

	return d.claimable(order, d.mustGetGroup(order.GroupID()))
}

// GetPendingFee returns prepaid fees held for a token.
func (d *dcaOrderV1) GetPendingFee(tokenPath string) int64 {
	return d.pendingFee(tokenPath)
}

// GetGroupIDs returns comma-separated group IDs in key order.
func (d *dcaOrderV1) GetGroupIDs(offset int, count int) string {
	if offset < 0 || count <= 0 {
		return ""
	}

	ids := []string{}
	d.store.GetGroups().IterateByOffset(offset, count, func(key string, _ any) bool {
		ids = append(ids, key)
		return false
	})

	return strings.Join(ids, ",")
}

// GetExecutableGroups returns up to count "<nextExecutionAt>|<groupID>"
// entries for groups executable now, oldest due first, strictly after the
// cursor entry. The schedule index is ordered by next execution time, so the
// scan stops at the first group that is not yet due.
func (d *dcaOrderV1) GetExecutableGroups(cursor string, count int) string {
	if count <= 0 {
		return ""
	}

	start := ""
	if cursor != "" {
		sep := strings.Index(cursor, "|")
		if sep <= 0 {
			panic(makeErrorWithDetails(errInvalidCursor, cursor))
		}

		next, err := strconv.ParseInt(cursor[:sep], 10, 64)
		if err != nil || next < 0 {
			panic(makeErrorWithDetails(errInvalidCursor, cursor))
		}

		start = utils.EncodeUint64(uint64(next)) + cursor[sep+1:]
	}

	// Rounds cannot run while the router, pool, or withdrawals are halted.
	if executionHalted() {
		return ""
	}

	now := time.Now().Unix()
	entries := []string{}
	d.store.GetScheduledGroups().Iterate(start, "", func(key string, value any) bool {
		if key == start && start != "" {
			return false
		}

		next := int64(utils.DecodeUint64(key[:8]))
		if next > now {
			return true
		}

		entries = append(entries, utils.FormatInt(next)+"|"+value.(string))

		return len(entries) >= count
	})

	return strings.Join(entries, ",")
}

// GetOrderIDsByOwner returns up to count order IDs owned by an address that
// are greater than startAfterID.
func (d *dcaOrderV1) GetOrderIDsByOwner(owner address, startAfterID uint64, count int) string {
	if count <= 0 {
		return ""
	}

	prefix := ownerOrderPrefix(owner)
	start := prefix
	if startAfterID > 0 {
		if startAfterID == ^uint64(0) {
			return ""
		}
		start = ownerOrderKey(owner, startAfterID+1)
	}

	ids := []string{}
	d.store.GetOrdersByOwner().Iterate(start, prefixEnd(prefix), func(_ string, value any) bool {
		ids = append(ids, utils.FormatUint(value.(uint64)))

		return len(ids) >= count
	})

	return strings.Join(ids, ",")
}

// claimable returns what the next Claim pays (at most one int64 transfer).
func (d *dcaOrderV1) claimable(order *dca.Order, group *dca.Group) int64 {
	endAcc, _ := settlementAcc(order, group)
	payout, _, _ := settleable(order.AmountPerExecution(), endAcc, order.AccDebtX128())

	return payout
}

func isExecutable(group *dca.Group, now int64) bool {
	return group.Rate() > 0 && now >= group.NextExecutionAt() && !executionHalted()
}

func executionHalted() bool {
	return halt.IsHaltedRouter() || halt.IsHaltedPool() || halt.IsHaltedWithdraw()
}

func marshal(fields map[string]*json.Node) string {
	b, err := json.Marshal(json.ObjectNode("", fields))
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func intNode(v int64) *json.Node {
	return json.StringNode("", utils.FormatInt(v))
}

func uintNode(v uint64) *json.Node {
	return json.StringNode("", utils.FormatUint(v))
}
