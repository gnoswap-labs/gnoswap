package dca_order

import (
	"chain"
	"strconv"
	"time"

	"chain/runtime"

	i256 "gno.land/p/gnoswap/int256"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

var Q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")

var (
	MIN_SQRT_RATIO = u256.MustFromDecimal("4295128739")
	MAX_SQRT_RATIO = u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")
)

// CreateOrder creates a new DCA order
func CreateOrder(
	_ realm,
	poolPath string,
	zeroForOne bool,
	intervalSeconds int64,
	amountPerExecution int64,
	totalExecutions int,
) string {
	caller := runtime.PreviousRealm().Address()
	now := time.Now().Unix()

	if amountPerExecution == 0 {
		panic(ErrInvalidAmount)
	}

	if totalExecutions <= 0 {
		panic(ErrInvalidExecutions)
	}

	if intervalSeconds <= 0 {
		panic(ErrInvalidInterval)
	}

	tokenIn, tokenOut, _ := parsePoolPath(poolPath)
	if !zeroForOne {
		tokenIn, tokenOut = tokenOut, tokenIn
	}

	totalDeposit := int64(totalExecutions) * amountPerExecution

	common.SafeGRC20TransferFrom(cross, tokenIn, caller, runtime.CurrentRealm().Address(), totalDeposit)

	orderID := nextOrderID(poolPath, zeroForOne, intervalSeconds)
	order := &Order{
		ID:                 orderID,
		Owner:              caller,
		PoolPath:           poolPath,
		TokenIn:            tokenIn,
		TokenOut:           tokenOut,
		ZeroForOne:         zeroForOne,
		AmountPerExecution: amountPerExecution,
		TotalExecutions:    totalExecutions,
		Interval:           intervalSeconds,
		CreatedAt:          now,
	}
	setOrder(order)

	addOrderToUserIndex(caller, orderID)

	group := getOrCreateOrderGroup(poolPath, zeroForOne, intervalSeconds)
	groupID := group.ID

	addOrderToGroupIndex(groupID, orderID)

	state := NewOrderState(orderID, group.AccumulatedOutX128PerAmount, now)
	state.DepositedAmount = totalDeposit
	setOrderState(group, state)

	group.DepositedAmount += amountPerExecution

	if group.AccumulatedTimestamp == 0 {
		group.AccumulatedTimestamp = now
	}

	endTimestamp := now + int64(totalExecutions)*intervalSeconds

	addOrderChange(group, endTimestamp, &OrderChange{
		OrderID:   orderID,
		Amount:    amountPerExecution,
		IsDeposit: false,
	})

	setOrderGroup(group)

	return orderID
}

// CancelOrder cancels an order and refunds remaining tokens
func CancelOrder(_ realm, orderID string) {
	caller := runtime.PreviousRealm().Address()
	now := time.Now().Unix()

	order, exists := getOrder(orderID)
	if !exists {
		panic(ErrOrderNotFound)
	}

	if order.Owner != caller {
		panic(ErrNotOrderOwner)
	}

	groupID := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupID)
	if !exists {
		panic(ErrGroupNotFound)
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		panic(ErrOrderStateNotFound)
	}

	processOrderChangesUntil(group, now)

	claimableOut := calculateClaimable(group, state, order)

	endTimestamp := order.CreatedAt + int64(order.TotalExecutions)*order.Interval

	var swappedAmount int64
	if now >= endTimestamp {
		swappedAmount = state.DepositedAmount
	} else {
		var executedIntervals int64
		if group.AccumulatedTimestamp > order.CreatedAt {
			executedIntervals = (group.AccumulatedTimestamp - order.CreatedAt) / order.Interval
			if executedIntervals < 0 {
				executedIntervals = 0
			}
		}
		swappedAmount = executedIntervals * order.AmountPerExecution
		if swappedAmount > state.DepositedAmount {
			swappedAmount = state.DepositedAmount
		}
	}

	remainingIn := state.DepositedAmount - swappedAmount

	if remainingIn > 0 {
		common.SafeGRC20Transfer(cross, order.TokenIn, caller, remainingIn)
	}

	if claimableOut > 0 {
		common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)
	}

	removeOrderChangesForOrder(group, orderID)

	if now < endTimestamp {
		group.DepositedAmount -= order.AmountPerExecution
		if group.DepositedAmount < 0 {
			group.DepositedAmount = 0
		}
	}

	setOrderGroup(group)

	deleteOrderState(group, orderID)
	removeOrderFromGroupIndex(groupID, order.ID)
	removeOrderFromUserIndex(caller, order.ID)
	deleteOrder(orderID)
}

// processOrderChangesUntil processes all pending order changes up to the given timestamp
func processOrderChangesUntil(group *OrderGroup, untilTimestamp int64) {
	timestampsToRemove := make([]int64, 0)

	iterateOrderChangesUntil(group, untilTimestamp, func(timestamp int64, changes []*OrderChange) bool {
		for _, change := range changes {
			if change.IsDeposit {
				group.DepositedAmount += change.Amount
			} else {
				group.DepositedAmount -= change.Amount
				if group.DepositedAmount < 0 {
					group.DepositedAmount = 0
				}

				state, exists := getOrderState(group, change.OrderID)
				if exists && state.FinalAccumulatorX128 == nil {
					state.FinalAccumulatorX128 = group.AccumulatedOutX128PerAmount.Clone()
					setOrderState(group, state)
				}
			}
		}
		timestampsToRemove = append(timestampsToRemove, timestamp)
		return false
	})

	for _, ts := range timestampsToRemove {
		removeOrderChanges(group, ts)
	}
}

// ExecuteBatchSwap executes swaps for all eligible groups
func ExecuteBatchSwap(_ realm) []BatchResult {
	now := time.Now().Unix()
	results := make([]BatchResult, 0)
	shouldProcessMissed := getProcessMissedIntervals()

	iterateOrderGroups(func(key string, group *OrderGroup) bool {
		for {
			if group.DepositedAmount == 0 {
				setOrderGroup(group)
				break
			}

			if group.AccumulatedTimestamp > 0 && now < group.AccumulatedTimestamp+group.Interval {
				setOrderGroup(group)
				break
			}

			nextExecTimestamp := now
			if group.AccumulatedTimestamp > 0 {
				nextExecTimestamp = group.AccumulatedTimestamp + group.Interval
			}

			result := executeGroupSwap(group, nextExecTimestamp)
			results = append(results, result)

			processOrderChangesUntil(group, nextExecTimestamp)

			if !shouldProcessMissed {
				break
			}

			if group.AccumulatedTimestamp >= now {
				break
			}
		}

		return false
	})

	return results
}

// executeGroupSwap executes a single swap for a group
// targetTimestamp is the timestamp for this execution (may be past time when processing missed intervals)
func executeGroupSwap(group *OrderGroup, targetTimestamp int64) BatchResult {
	result := BatchResult{
		GroupID: group.ID,
		Success: false,
	}

	amountIn := group.DepositedAmount
	if amountIn == 0 {
		result.Error = "no amount to swap"
		return result
	}

	amountOut, err := executeSwap(group.PoolPath, group.ZeroForOne, amountIn)
	if err != nil {
		result.Error = err.Error()
		return result
	}

	if group.DepositedAmount > 0 {
		amountOutU256 := u256.NewUintFromInt64(amountOut)
		depositedU256 := u256.NewUintFromInt64(group.DepositedAmount)

		numerator := u256.Zero().Mul(amountOutU256, Q128)
		delta := u256.Zero().Div(numerator, depositedU256)

		group.AccumulatedOutX128PerAmount = u256.Zero().Add(
			group.AccumulatedOutX128PerAmount,
			delta,
		)
	}

	group.AccumulatedTimestamp = targetTimestamp
	setOrderGroup(group)

	result.AmountIn = amountIn
	result.AmountOut = amountOut
	result.Success = true

	return result
}

// Claim claims accumulated output tokens for an order
func Claim(_ realm, orderID string) int64 {
	caller := runtime.PreviousRealm().Address()

	order, exists := getOrder(orderID)
	if !exists {
		panic(ErrOrderNotFound)
	}

	if order.Owner != caller {
		panic(ErrNotOrderOwner)
	}

	groupID := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)

	group, exists := getOrderGroup(groupID)
	if !exists {
		panic(ErrGroupNotFound)
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		panic(ErrOrderStateNotFound)
	}

	claimableOut := calculateClaimable(group, state, order)
	if claimableOut == 0 {
		return 0
	}

	common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)

	state.ClaimedAmount = 0
	state.OutAmountDebtX128 = group.AccumulatedOutX128PerAmount.Clone()
	state.ClaimedTimestamp = time.Now().Unix()
	setOrderState(group, state)

	return claimableOut
}

// ClaimAll claims rewards from all orders owned by caller
func ClaimAll(_ realm) map[string]int64 {
	caller := runtime.PreviousRealm().Address()
	orderIDs := getOrderIDsByUser(caller)

	claimedByToken := make(map[string]int64)

	for _, orderID := range orderIDs {
		order, exists := getOrder(orderID)
		if !exists {
			continue
		}

		groupID := makeGroupID(order.PoolPath, order.ZeroForOne, order.Interval)
		group, exists := getOrderGroup(groupID)
		if !exists {
			continue
		}

		state, exists := getOrderState(group, orderID)
		if !exists {
			continue
		}

		claimableOut := calculateClaimable(group, state, order)
		if claimableOut == 0 {
			continue
		}

		common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)

		state.ClaimedAmount = 0
		state.AccumulatedOut += claimableOut
		state.OutAmountDebtX128 = group.AccumulatedOutX128PerAmount.Clone()
		state.ClaimedTimestamp = time.Now().Unix()
		setOrderState(group, state)

		prev, _ := claimedByToken[order.TokenOut]
		claimedByToken[order.TokenOut] = prev + claimableOut
	}

	return claimedByToken
}

func claimByOrder(group *OrderGroup, state *OrderState, order *Order) int64 {
	claimable := calculateClaimable(group, state, order)
	if claimable == 0 {
		return 0
	}

	state.ClaimedAmount = 0
	state.OutAmountDebtX128 = group.AccumulatedOutX128PerAmount.Clone()
	state.ClaimedTimestamp = time.Now().Unix()
	setOrderState(group, state)

	return claimable
}

// calculateClaimable calculates claimable output for an order state
func calculateClaimable(group *OrderGroup, state *OrderState, order *Order) int64 {
	accumulatorX128 := group.AccumulatedOutX128PerAmount
	if state.FinalAccumulatorX128 != nil {
		accumulatorX128 = state.FinalAccumulatorX128
	}

	if accumulatorX128.Lte(state.OutAmountDebtX128) {
		return 0
	}

	deltaX128 := u256.Zero().Sub(accumulatorX128, state.OutAmountDebtX128)

	activeU256 := u256.NewUintFromInt64(order.AmountPerExecution)
	result := u256.MulDiv(deltaX128, activeU256, Q128)

	totalOwed := result.Int64()
	claimable := totalOwed - state.ClaimedAmount
	if claimable <= 0 {
		return 0
	}

	chain.Emit(
		"ClaimDCAOrder",
		"orderID", order.ID,
		"claimable", strconv.FormatInt(claimable, 10),
		"totalOwed", strconv.FormatInt(totalOwed, 10),
		"ClaimedAmount", strconv.FormatInt(state.ClaimedAmount, 10))

	return claimable
}

func parsePoolPath(poolPath string) (string, string, uint32) {
	token0, token1, fee := pool.ParsePoolPath(poolPath)
	return token0, token1, fee
}

func executeSwap(poolPath string, zeroForOne bool, amountIn int64) (int64, error) {
	token0, token1, fee := parsePoolPath(poolPath)

	currentAddress := runtime.CurrentRealm().Address()
	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())
	amountInStr := strconv.FormatInt(amountIn, 10)

	var sqrtPriceLimitX96 string
	if zeroForOne {
		sqrtPriceLimitX96 = u256.Zero().Add(MIN_SQRT_RATIO, u256.One()).ToString()
	} else {
		sqrtPriceLimitX96 = u256.Zero().Sub(MAX_SQRT_RATIO, u256.One()).ToString()
	}

	// Execute swap via pool
	_, amountOut := pool.Swap(
		cross,
		token0,
		token1,
		fee,
		currentAddress,
		zeroForOne,
		amountInStr,
		sqrtPriceLimitX96,
		currentAddress,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(cross, token0, poolAddr, int64(amount0Delta))
			}

			if amount1Delta > 0 {
				common.SafeGRC20Transfer(cross, token1, poolAddr, int64(amount1Delta))
			}

			return nil
		},
	)

	amountOutInt256 := i256.MustFromDecimal(amountOut)
	return amountOutInt256.Abs().Int64(), nil
}

// SetProcessMissedIntervals sets whether missed intervals should be processed
func SetProcessMissedIntervals(_ realm, value bool) {
	caller := runtime.PreviousRealm().Address()
	if caller != getAdmin() {
		panic(ErrNotAdmin)
	}

	setProcessMissedIntervals(value)
}
