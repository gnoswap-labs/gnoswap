package dca_order

import (
	"strconv"
	"time"

	"chain/runtime"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

// Q128 is 2^128 for fixed-point math
var Q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")

// ============================================
// 1. Order Creation
// ============================================

// CreateOrder creates a new DCA order
func CreateOrder(
	poolPath string,
	zeroForOne bool,
	amountPerExecution int64,
	totalExecutions int,
	intervalSeconds int64,
) int64 {
	caller := runtime.PreviousRealm().Address()
	now := time.Now().Unix()

	// Validate inputs
	if amountPerExecution == 0 {
		panic(ErrInvalidAmount)
	}
	if totalExecutions <= 0 {
		panic(ErrInvalidExecutions)
	}
	if intervalSeconds <= 0 {
		panic(ErrInvalidInterval)
	}

	// Get pool info
	tokenIn, tokenOut, _ := parsePoolPath(poolPath)

	// Calculate total deposit amount
	totalDeposit := int64(totalExecutions) * amountPerExecution

	// Transfer tokens to escrow
	common.SafeGRC20TransferFrom(cross, tokenIn, caller, runtime.CurrentRealm().Address(), totalDeposit)

	// Create order
	orderID := nextOrderID()
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

	// Add to indices
	addOrderToUserIndex(caller, orderID)

	// Get or create order group
	group := getOrCreateOrderGroup(poolPath, zeroForOne, intervalSeconds)
	groupKey := group.Key

	addOrderToGroupIndex(groupKey, orderID)

	// Create order state with current accumulator as debt
	state := NewOrderState(orderID, group.AccumulatedOutX128PerAmount, now)
	state.DepositedAmount = totalDeposit
	setOrderState(group, state)

	// Update group's deposited amount
	group.DepositedAmount += totalDeposit
	setOrderGroup(group)

	return orderID
}

// ============================================
// 2. Order Cancellation
// ============================================

// CancelOrder cancels an order and refunds remaining tokens
func CancelOrder(orderID int64) {
	caller := runtime.PreviousRealm().Address()

	order, exists := getOrder(orderID)
	if !exists {
		panic(ErrOrderNotFound)
	}

	if order.Owner != caller {
		panic(ErrNotOrderOwner)
	}

	// Get group and state
	groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		panic(ErrGroupNotFound)
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		panic(ErrOrderStateNotFound)
	}

	// Calculate claimable output
	claimableOut := calculateClaimable(group, state)

	// Refund remaining input tokens
	remainingIn := state.DepositedAmount
	if remainingIn > 0 {
		common.SafeGRC20Transfer(cross, order.TokenIn, caller, remainingIn)
	}

	// Transfer accumulated output
	if claimableOut > 0 {
		common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)
	}

	// Update group
	group.DepositedAmount -= state.DepositedAmount
	setOrderGroup(group)

	// Clean up
	deleteOrderState(group, orderID)
	removeOrderFromGroupIndex(groupKey, orderID)
	removeOrderFromUserIndex(caller, orderID)
	deleteOrder(orderID)
}

// ============================================
// 3. Batch Swap Execution (Admin)
// ============================================

// ExecuteBatchSwap executes swaps for all eligible groups
func ExecuteBatchSwap() []BatchResult {
	now := time.Now().Unix()
	results := make([]BatchResult, 0)

	// Iterate through all groups
	iterateOrderGroups(func(key string, group *OrderGroup) bool {
		// Skip if no deposited amount
		if group.DepositedAmount == 0 {
			return false
		}

		// Check if execution is due
		if group.AccumulatedTimestamp > 0 && now < group.AccumulatedTimestamp+group.Interval {
			return false
		}

		// Execute swap for this group
		result := executeGroupSwap(group, now)
		results = append(results, result)

		return false
	})

	return results
}

// executeGroupSwap executes a single swap for a group
func executeGroupSwap(group *OrderGroup, now int64) BatchResult {
	result := BatchResult{
		GroupKey: group.Key,
		Success:  false,
	}

	// Calculate amount to swap (deposited amount that hasn't been used)
	amountIn := group.DepositedAmount
	if amountIn == 0 {
		result.Error = "no amount to swap"
		return result
	}

	// Execute swap
	amountOut, err := executeSwap(group.PoolPath, group.ZeroForOne, amountIn)
	if err != "" {
		result.Error = err
		return result
	}

	// Update accumulator
	// accumulatedOutX128PerAmount += (amountOut * Q128) / depositedAmount
	if group.DepositedAmount > 0 {
		amountOutU256 := u256.NewUint(amountOut)
		depositedU256 := u256.NewUint(group.DepositedAmount)

		// (amountOut * Q128) / depositedAmount
		numerator := new(u256.Uint).Mul(amountOutU256, Q128)
		delta := new(u256.Uint).Div(numerator, depositedU256)

		group.AccumulatedOutX128PerAmount = new(u256.Uint).Add(
			group.AccumulatedOutX128PerAmount,
			delta,
		)
	}

	group.AccumulatedTimestamp = now
	setOrderGroup(group)

	result.AmountIn = amountIn
	result.AmountOut = amountOut
	result.Success = true

	return result
}

// ============================================
// 4. Claim Rewards
// ============================================

// Claim claims accumulated output tokens for an order
func Claim(orderID int64) int64 {
	caller := runtime.PreviousRealm().Address()

	order, exists := getOrder(orderID)
	if !exists {
		panic(ErrOrderNotFound)
	}

	if order.Owner != caller {
		panic(ErrNotOrderOwner)
	}

	// Get group and state
	groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
	group, exists := getOrderGroup(groupKey)
	if !exists {
		panic(ErrGroupNotFound)
	}

	state, exists := getOrderState(group, orderID)
	if !exists {
		panic(ErrOrderStateNotFound)
	}

	// Calculate claimable
	claimableOut := calculateClaimable(group, state)
	if claimableOut == 0 {
		panic(ErrNothingToClaim)
	}

	// Transfer output tokens
	common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)

	// Update state
	state.ClaimedAmount += claimableOut
	state.AccumulatedOut += claimableOut
	state.OutAmountDebtX128 = group.AccumulatedOutX128PerAmount.Clone()
	state.ClaimedTimestamp = time.Now().Unix()
	setOrderState(group, state)

	return claimableOut
}

// ClaimAll claims rewards from all orders owned by caller
func ClaimAll() map[string]int64 {
	caller := runtime.PreviousRealm().Address()
	orderIDs := getOrderIDsByUser(caller)

	claimedByToken := make(map[string]int64)

	for _, orderID := range orderIDs {
		order, exists := getOrder(orderID)
		if !exists {
			continue
		}

		groupKey := makeGroupKey(order.PoolPath, order.ZeroForOne, order.Interval)
		group, exists := getOrderGroup(groupKey)
		if !exists {
			continue
		}

		state, exists := getOrderState(group, orderID)
		if !exists {
			continue
		}

		claimableOut := calculateClaimable(group, state)
		if claimableOut == 0 {
			continue
		}

		// Transfer output tokens
		common.SafeGRC20Transfer(cross, order.TokenOut, caller, claimableOut)

		// Update state
		state.ClaimedAmount += claimableOut
		state.AccumulatedOut += claimableOut
		state.OutAmountDebtX128 = group.AccumulatedOutX128PerAmount.Clone()
		state.ClaimedTimestamp = time.Now().Unix()
		setOrderState(group, state)

		// Accumulate by token
		prev, _ := claimedByToken[order.TokenOut]
		claimedByToken[order.TokenOut] = prev + claimableOut
	}

	return claimedByToken
}

// ============================================
// Internal Helper Functions
// ============================================

// calculateClaimable calculates claimable output for an order state
// Formula: (accumulatedX128 - debtX128) * depositedAmount / Q128
func calculateClaimable(group *OrderGroup, state *OrderState) int64 {
	// accumulatedX128 - debtX128
	if group.AccumulatedOutX128PerAmount.Lte(state.OutAmountDebtX128) {
		return 0
	}

	deltaX128 := new(u256.Uint).Sub(group.AccumulatedOutX128PerAmount, state.OutAmountDebtX128)

	// deltaX128 * depositedAmount / Q128
	depositedU256 := u256.NewUint(state.DepositedAmount)
	numerator := new(u256.Uint).Mul(deltaX128, depositedU256)
	result := new(u256.Uint).Div(numerator, Q128)

	// Subtract already claimed
	totalOwed := result.int64()
	if totalOwed <= state.AccumulatedOut {
		return 0
	}

	return totalOwed - state.AccumulatedOut
}

func parsePoolPath(poolPath string) (string, string, uint32) {
	token0, token1, fee := pool.ParsePoolPath(poolPath)
	return token0, token1, fee
}

func executeSwap(poolPath string, zeroForOne bool, amountIn int64) (int64, string) {
	token0, token1, fee := parsePoolPath(poolPath)

	currentAddress := runtime.CurrentRealm().Address()
	amountInStr := strconv.FormatInt(amountIn, 10)

	// Execute swap via pool
	_, amountOut :=
		pool.Swap(
			cross,
			token0,
			token1,
			fee,
			currentAddress,
			zeroForOne,
			amountInStr,
			"0",
			currentAddress,
			func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
				if amount0Delta > 0 {
					common.SafeGRC20Transfer(cross, token0, currentAddress, int64(amount0Delta))
				}

				if amount1Delta > 0 {
					common.SafeGRC20Transfer(cross, token1, currentAddress, int64(amount1Delta))
				}

				return nil
			},
		)

	amountOutInt256 := i256.MustFromDecimal(amountOut)
	return amountOutInt256.Abs().int64(), ""
}
