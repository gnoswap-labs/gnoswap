package dca_order

// CreateOrder creates a DCA order that sells amountPerExecution of tokenIn in
// poolPath every interval seconds, totalExecutions times.
//
// The caller must approve Address() for
// amountPerExecution*totalExecutions plus the creation fee (see GetConfigJSON).
// Orders with the same pool, input token, and interval share one group and
// are executed together.
//
// Parameters:
//   - cur: current realm context.
//   - poolPath: pool used for every round (token0:token1:fee).
//   - tokenIn: token to sell; must be token0 or token1 of the pool.
//   - interval: seconds between rounds; one of GetConfigJSON().allowedIntervals.
//   - amountPerExecution: input sold per round.
//   - totalExecutions: number of rounds.
//   - maxFeeBps: highest creation fee the caller accepts; reverts if the
//     configured fee is higher (guards against a fee change before inclusion).
//
// Returns:
//   - orderID: identifier of the new order.
//
// Halt check: reverts while the Router, Pool, or Withdraw scope is halted.
func CreateOrder(
	cur realm,
	poolPath string,
	tokenIn string,
	interval int64,
	amountPerExecution int64,
	totalExecutions int64,
	maxFeeBps int64,
) uint64 {
	return getImplementation().CreateOrder(0, cur, poolPath, tokenIn, interval, amountPerExecution, totalExecutions, maxFeeBps)
}

// CancelOrder settles accrued output, refunds unsold input, and closes the
// order. The prepaid creation fee is not refunded. Owner only.
//
// Returns:
//   - refundIn: unsold input refunded to the owner.
//   - claimedOut: output transferred to the owner by this call.
//
// Halt check: reverts while withdrawals are halted.
func CancelOrder(cur realm, orderID uint64) (int64, int64) {
	return getImplementation().CancelOrder(0, cur, orderID)
}

// Claim transfers accrued output to the order owner. Callable by anyone;
// proceeds always go to the owner, so keepers may deliver output.
//
// Returns:
//   - claimed: output transferred.
//
// Halt check: reverts while withdrawals are halted.
func Claim(cur realm, orderID uint64) int64 {
	return getImplementation().Claim(0, cur, orderID)
}

// ExecuteGroup runs the next round of a group. Permissionless: anyone may
// call it once the group's next execution time has passed.
//
// Parameters:
//   - groupID: group identifier (see GetExecutableGroups).
//   - expectedAmountIn: input the caller quoted amountOutMin for (the group
//     rate it read). If the rate changed before execution, amountOutMin is
//     scaled to the actual input, keeping the same minimum price. 0 means
//     amountOutMin applies unscaled.
//   - amountOutMin: optional minimum router output; 0 disables.
//
// Returns:
//   - amountIn: input sold this round.
//   - amountOut: output received after the router fee.
//
// Halt check: reverts while the Router, Pool, or Withdraw scope is halted.
func ExecuteGroup(cur realm, groupID string, expectedAmountIn int64, amountOutMin int64) (int64, int64) {
	return getImplementation().ExecuteGroup(0, cur, groupID, expectedAmountIn, amountOutMin)
}

// SetCreationFeeBps sets the prepaid creation fee. Admin or governance only.
func SetCreationFeeBps(cur realm, feeBps int64) {
	getImplementation().SetCreationFeeBps(0, cur, feeBps)
}

// SetOrderLimits sets the minimum input per round and maximum rounds per
// order. Admin or governance only.
func SetOrderLimits(cur realm, minAmountPerExecution int64, maxTotalExecutions int64) {
	getImplementation().SetOrderLimits(0, cur, minAmountPerExecution, maxTotalExecutions)
}

// WithdrawFee withdraws prepaid creation fees. Admin or governance only.
func WithdrawFee(cur realm, tokenPath string, recipient address, amount int64) {
	getImplementation().WithdrawFee(0, cur, tokenPath, recipient, amount)
}
