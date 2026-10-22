package dca_order

import (
	"chain"

	"gno.land/p/gnoswap/utils/v1"

	dca "gno.land/r/gnoswap/test/dca_order"
)

// Events carry the persisted accumulator state (accX128, round, rate) so that
// off-chain indexers can reproduce claimable amounts without querying state:
// claimable = amountPerExecution * (acc(min(round, endRound)) - accDebtX128) / 2^128.

func emitGroupCreated(prevAddr address, prevRealm string, group *dca.Group) {
	chain.Emit(
		"DCAGroupCreated",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"groupId", group.ID(),
		"poolPath", group.PoolPath(),
		"tokenIn", group.TokenIn(),
		"tokenOut", group.TokenOut(),
		"zeroForOne", utils.FormatBool(group.ZeroForOne()),
		"interval", utils.FormatInt(group.Interval()),
		"nextExecutionAt", utils.FormatInt(group.NextExecutionAt()),
	)
}

func emitOrderCreated(prevAddr address, prevRealm string, order *dca.Order, group *dca.Group, depositAmount int64) {
	chain.Emit(
		"DCAOrderCreated",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"orderId", utils.FormatUint(order.ID()),
		"owner", order.Owner().String(),
		"groupId", order.GroupID(),
		"poolPath", group.PoolPath(),
		"tokenIn", group.TokenIn(),
		"tokenOut", group.TokenOut(),
		"zeroForOne", utils.FormatBool(group.ZeroForOne()),
		"interval", utils.FormatInt(group.Interval()),
		"amountPerExecution", utils.FormatInt(order.AmountPerExecution()),
		"totalExecutions", utils.FormatInt(order.TotalExecutions()),
		"depositAmount", utils.FormatInt(depositAmount),
		"feeAmount", utils.FormatInt(order.FeePaid()),
		"startRound", utils.FormatUint(order.StartRound()),
		"endRound", utils.FormatUint(order.EndRound()),
		"accDebtX128", order.AccDebtX128().ToString(),
		"groupRate", utils.FormatInt(group.Rate()),
		"groupNextExecutionAt", utils.FormatInt(group.NextExecutionAt()),
	)
}

func emitGroupExecuted(
	prevAddr address,
	prevRealm string,
	group *dca.Group,
	scheduledAt int64,
	amountIn int64,
	amountOut int64,
	endedRate int64,
) {
	chain.Emit(
		"DCAGroupExecuted",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"groupId", group.ID(),
		"poolPath", group.PoolPath(),
		"tokenIn", group.TokenIn(),
		"tokenOut", group.TokenOut(),
		"round", utils.FormatUint(group.Round()),
		"amountIn", utils.FormatInt(amountIn),
		"amountOut", utils.FormatInt(amountOut),
		"accX128", group.AccX128().ToString(),
		"endedRate", utils.FormatInt(endedRate),
		"nextRate", utils.FormatInt(group.Rate()),
		"scheduledAt", utils.FormatInt(scheduledAt),
		"executedAt", utils.FormatInt(group.LastExecutedAt()),
		"nextExecutionAt", utils.FormatInt(group.NextExecutionAt()),
	)
}

func emitOrderClaimed(prevAddr address, prevRealm string, order *dca.Order, group *dca.Group, amount int64) {
	chain.Emit(
		"DCAOrderClaimed",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"orderId", utils.FormatUint(order.ID()),
		"owner", order.Owner().String(),
		"groupId", order.GroupID(),
		"tokenOut", group.TokenOut(),
		"amount", utils.FormatInt(amount),
		"claimedOut", order.ClaimedOut().ToString(),
		"accDebtX128", order.AccDebtX128().ToString(),
		"status", order.Status().String(),
	)
}

func emitOrderCancelled(prevAddr address, prevRealm string, order *dca.Order, group *dca.Group, claimed int64) {
	chain.Emit(
		"DCAOrderCancelled",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"orderId", utils.FormatUint(order.ID()),
		"owner", order.Owner().String(),
		"groupId", order.GroupID(),
		"tokenIn", group.TokenIn(),
		"tokenOut", group.TokenOut(),
		"refundIn", utils.FormatInt(order.RefundedIn()),
		"claimedAmount", utils.FormatInt(claimed),
		"claimedOut", order.ClaimedOut().ToString(),
		"accDebtX128", order.AccDebtX128().ToString(),
		"status", order.Status().String(),
		"groupRate", utils.FormatInt(group.Rate()),
	)
}

func emitConfigUpdated(prevAddr address, prevRealm string, key string, prevValue int64, newValue int64) {
	chain.Emit(
		"DCAConfigUpdated",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"key", key,
		"prevValue", utils.FormatInt(prevValue),
		"newValue", utils.FormatInt(newValue),
	)
}

func emitFeeWithdrawn(prevAddr address, prevRealm string, tokenPath string, recipient address, amount int64, remaining int64) {
	chain.Emit(
		"DCAFeeWithdrawn",
		"prevAddr", prevAddr.String(),
		"prevRealm", prevRealm,
		"tokenPath", tokenPath,
		"recipient", recipient.String(),
		"amount", utils.FormatInt(amount),
		"remaining", utils.FormatInt(remaining),
	)
}
