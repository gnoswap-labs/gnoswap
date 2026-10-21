package v1

import (
	"chain"
	"strconv"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	lo "gno.land/r/gnoswap/limit_order"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"
)

// CreateOrder creates a new limit order
func (l *limitOrderV1) CreateOrder(
	_ int,
	rlm realm,
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount uint64,
	takingAmount uint64,
	slippageBps uint64,
	feeBps uint64,
	expiredAt int64,
	caller address,
) uint64 {
	access.AssertIsRlmCurrent(0, rlm)
	assertCallerMatches(0, rlm, caller)

	orderId := l.store.GetOrderNextID()

	// Validations
	l.validateCreateOrder(
		poolPath,
		inputMint,
		outputMint,
		makingAmount,
		takingAmount,
		slippageBps,
		feeBps,
		expiredAt,
	)

	// Convert amounts to u256
	makingAmountU256 := u256.NewUint(makingAmount)
	takingAmountU256 := u256.NewUint(takingAmount)

	// Increment order ID
	mustStore(l.store.SetOrderNextID(0, rlm, orderId+1))

	// Create order
	order := lo.NewLimitOrder(
		orderId,
		caller,
		poolPath,
		inputMint,
		outputMint,
		makingAmountU256,
		takingAmountU256,
		slippageBps,
		feeBps,
		expiredAt,
	)

	// Deposit tokens (escrow)
	amount64 := safeConvertToInt64(makingAmountU256)
	common.SafeGRC20TransferFrom(0, rlm, inputMint.String(), caller, l.contractAddr, amount64)
	order.SetDeposited(true)

	// Store order
	mustStore(l.store.SetOrder(0, rlm, orderId, *order))
	mustStore(l.store.AddOwnerOrder(0, rlm, caller, orderId))

	return orderId
}

// ExecuteOrder executes a limit order when conditions are met
func (l *limitOrderV1) ExecuteOrder(_ int, rlm realm, orderId uint64, caller address) {
	access.AssertIsRlmCurrent(0, rlm)
	assertCallerMatches(0, rlm, caller)
	order, exists := l.store.GetOrder(orderId)
	if !exists {
		panic(lo.ErrOrderNotFound)
	}

	// Validation
	l.validateExecuteOrder(&order)

	// Check if price condition is met
	currentPrice := l.getCurrentPrice(order.PoolPath(), order.InputMint(), order.OutputMint())
	if !order.CanExecute(currentPrice) {
		panic(lo.ErrPriceNotReached)
	}

	// Get minimum acceptable output based on execution mode
	minOutput := order.GetMinimumOutput()

	// Execute swap through router
	routerAddr := chain.PackageAddress("gno.land/r/gnoswap/router")
	approveAmount := safeConvertToInt64(order.MakingAmount())
	common.SafeGRC20Approve(0, rlm, order.InputMint().String(), routerAddr, approveAmount)
	deadline := time.Now().Unix() + 300
	routePath := buildOrderRoutePath(&order)

	_, amountOutStr := router.ExactInSingleSwapRoute(
		cross(rlm),
		order.InputMint().String(),
		order.OutputMint().String(),
		order.MakingAmount().ToString(),
		routePath,
		minOutput.ToString(),
		"0",
		deadline,
		"",
	)
	amountOut := u256.MustFromDecimal(amountOutStr)

	// Calculate keeper fee from output
	keeperFeeAmount := calculateKeeperFeeFromOutput(amountOut, order.FeeBps())

	if keeperFeeAmount.Gt(amountOut) {
		panic(lo.ErrInsufficientOutput)
	}

	userAmount := u256.Zero().Sub(amountOut, keeperFeeAmount)

	// Transfer tokens
	userAmountInt := safeConvertToInt64(userAmount)
	common.SafeGRC20Transfer(0, rlm, order.OutputMint().String(), order.Owner(), userAmountInt)
	keeperFeeInt := safeConvertToInt64(keeperFeeAmount)
	common.SafeGRC20Transfer(0, rlm, order.OutputMint().String(), caller, keeperFeeInt)

	// Update order status
	order.SetStatus(lo.OrderStatusExecuted)
	mustStore(l.store.SetOrder(0, rlm, orderId, order))
}

// CancelOrder cancels an active limit order
func (l *limitOrderV1) CancelOrder(_ int, rlm realm, orderId uint64, caller address) {
	access.AssertIsRlmCurrent(0, rlm)
	assertCallerMatches(0, rlm, caller)
	// Get order
	order, exists := l.store.GetOrder(orderId)
	if !exists {
		panic(lo.ErrOrderNotFound)
	}

	// Validate caller is owner
	if order.Owner() != caller {
		panic(lo.ErrUnauthorized)
	}

	// Validate order can be cancelled
	l.validateCancelOrder(&order)

	// Refund tokens
	if order.Deposited() {
		refundAmount := safeConvertToInt64(order.MakingAmount())
		common.SafeGRC20Transfer(0, rlm, order.InputMint().String(), order.Owner(), refundAmount)
		order.SetDeposited(false)
	}

	// Update order status
	order.SetStatus(lo.OrderStatusCancelled)
	mustStore(l.store.SetOrder(0, rlm, orderId, order))

	// Remove from owner index
	mustStore(l.store.RemoveOwnerOrder(0, rlm, order.Owner(), orderId))
}

// CleanupExpiredOrders cleans up expired orders
func (l *limitOrderV1) CleanupExpiredOrders(_ int, rlm realm, maxCount uint64) uint64 {
	access.AssertIsRlmCurrent(0, rlm)
	orders := l.store.GetOrders()
	cleaned := uint64(0)
	currentTime := time.Now().Unix()

	// First, collect expired order IDs
	var expiredOrderIDs []uint64
	orders.Iterate("", "", func(key string, value interface{}) bool {
		if uint64(len(expiredOrderIDs)) >= maxCount {
			return true // stop iteration
		}

		order := value.(lo.LimitOrder)
		if order.Status() == lo.OrderStatusActive && currentTime >= order.ExpiredAt() {
			expiredOrderIDs = append(expiredOrderIDs, order.ID())
		}

		return false // continue
	})

	// Then, process each expired order outside the closure
	for _, orderId := range expiredOrderIDs {
		order, exists := l.store.GetOrder(orderId)
		if !exists {
			continue
		}

		// Refund tokens to owner
		if order.Deposited() {
			expiredRefundAmount := safeConvertToInt64(order.MakingAmount())
			common.SafeGRC20Transfer(0, rlm, order.InputMint().String(), order.Owner(), expiredRefundAmount)
			order.SetDeposited(false)
		}

		// Mark as expired
		order.SetStatus(lo.OrderStatusExpired)
		mustStore(l.store.SetOrder(0, rlm, order.ID(), order))
		mustStore(l.store.RemoveOwnerOrder(0, rlm, order.Owner(), order.ID()))

		cleaned++
	}

	return cleaned
}

// Helper functions

func assertCallerMatches(_ int, rlm realm, caller address) {
	if caller != rlm.Previous().Address() {
		panic(lo.ErrUnauthorized)
	}
}

func mustStore(err error) {
	if err != nil {
		panic(err)
	}
}

func (l *limitOrderV1) validateCreateOrder(
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount uint64,
	takingAmount uint64,
	slippageBps uint64,
	feeBps uint64,
	expiredAt int64,
) {
	if poolPath == "" {
		panic(lo.ErrInvalidPoolPath)
	}

	if inputMint == "" {
		panic(lo.ErrInvalidTokenIn)
	}

	if outputMint == "" {
		panic(lo.ErrInvalidTokenOut)
	}

	if inputMint == outputMint {
		panic(lo.ErrSameToken)
	}

	if makingAmount == 0 {
		panic(lo.ErrInvalidAmountIn)
	}

	if takingAmount == 0 {
		panic(lo.ErrInvalidMinAmountOut)
	}

	if feeBps < lo.MIN_KEEPER_FEE_BPS || feeBps > lo.MAX_KEEPER_FEE_BPS {
		panic(lo.ErrInvalidKeeperFee)
	}

	// Slippage validation (optional, can be 0 for exact mode)
	if slippageBps > 1000 { // Max 10% slippage
		panic(lo.ErrInvalidSlippage)
	}

	// Validate pool exists and tokens match pool path
	l.validatePoolAndTokens(poolPath, inputMint, outputMint)

	currentTime := time.Now().Unix()
	duration := expiredAt - currentTime

	if duration < lo.MIN_ORDER_DEADLINE {
		panic(lo.ErrDeadlineTooShort)
	}

	if duration > lo.MAX_ORDER_DEADLINE {
		panic(lo.ErrDeadlineTooLong)
	}
}

func (l *limitOrderV1) validateExecuteOrder(order *lo.LimitOrder) {
	if order.Status() != lo.OrderStatusActive {
		panic(lo.ErrOrderNotActive)
	}

	if !order.Deposited() {
		panic(lo.ErrOrderNotDeposited)
	}

	if order.IsExpired() {
		panic(lo.ErrOrderExpired)
	}
}

func (l *limitOrderV1) validateCancelOrder(order *lo.LimitOrder) {
	if order.Status() == lo.OrderStatusExecuted {
		panic(lo.ErrAlreadyExecuted)
	}

	if order.Status() == lo.OrderStatusCancelled {
		panic(lo.ErrAlreadyCancelled)
	}
}

func calculateKeeperFeeFromOutput(amountOut *u256.Uint, feeBps uint64) *u256.Uint {
	fee := u256.Zero().Mul(amountOut, u256.NewUint(feeBps))
	fee = u256.Zero().Div(fee, u256.NewUint(lo.BPS_DENOMINATOR))
	return fee
}

func (l *limitOrderV1) getCurrentPrice(poolPath string, inputMint, outputMint address) *u256.Uint {
	// Parse poolPath: "token0:token1:fee"
	parts := strings.Split(poolPath, ":")
	if len(parts) != 3 {
		panic(lo.ErrInvalidPoolPath)
	}
	token0 := parts[0]
	token1 := parts[1]
	feeValue, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		panic(lo.ErrInvalidPoolPath)
	}
	fee := uint32(feeValue)

	// Get pool to check current price
	pool := getPool(token0, token1, fee)
	if pool == nil {
		panic(lo.ErrInvalidPoolPath)
	}
	slot0 := pool.Slot0()
	sqrtPriceX96 := slot0.SqrtPriceX96()
	token0Path := pool.Token0Path()
	token1Path := pool.Token1Path()

	// sqrtPriceX96 represents sqrt(token1/token0) * 2^96
	// We need price in outputMint/inputMint * 2^96 scale (same as GetLimitPrice)

	q96 := u256.MustFromDecimal("79228162514264337593543950336") // 2^96

	// Calculate sqrtPriceX96^2 / q96 = token1/token0 * q96
	sqrtSq := u256.Zero().Mul(sqrtPriceX96, sqrtPriceX96)
	priceScaledQ96 := u256.Zero().Div(sqrtSq, q96) // token1/token0 * q96

	if inputMint.String() == token0Path && outputMint.String() == token1Path {
		// Want token1/token0 * q96, which we already have
		return priceScaledQ96
	} else if inputMint.String() == token1Path && outputMint.String() == token0Path {
		// Want token0/token1 * q96 = q96^2 / (token1/token0 * q96) = q96^2 / priceScaledQ96
		if priceScaledQ96.IsZero() {
			return u256.Zero()
		}
		q96Sq := u256.Zero().Mul(q96, q96) // 2^192
		return u256.Zero().Div(q96Sq, priceScaledQ96)
	}

	// This should never be reached if validatePoolAndTokens was called during order creation
	panic(lo.ErrTokenPoolMismatch)
}

// validatePoolAndTokens validates that the pool exists and tokens match the pool path
func (l *limitOrderV1) validatePoolAndTokens(poolPath string, inputMint, outputMint address) {
	// Parse poolPath: "token0:token1:fee"
	parts := strings.Split(poolPath, ":")
	if len(parts) != 3 {
		panic(lo.ErrInvalidPoolPath)
	}
	token0 := parts[0]
	token1 := parts[1]
	feeValue, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		panic(lo.ErrInvalidPoolPath)
	}
	fee := uint32(feeValue)

	// Verify pool exists
	pool := getPool(token0, token1, fee)
	if pool == nil {
		panic(lo.ErrPoolNotFound)
	}
	token0Path := pool.Token0Path()
	token1Path := pool.Token1Path()

	// Verify tokens match pool (in either direction)
	inputStr := inputMint.String()
	outputStr := outputMint.String()

	validDirection1 := inputStr == token0Path && outputStr == token1Path
	validDirection2 := inputStr == token1Path && outputStr == token0Path

	if !validDirection1 && !validDirection2 {
		panic(lo.ErrTokenPoolMismatch)
	}
}

// buildOrderRoutePath orders the pool route in the swap direction; pool IDs are canonical.
func buildOrderRoutePath(order *lo.LimitOrder) string {
	poolPath := order.PoolPath()
	feeSeparator := strings.LastIndex(poolPath, ":")
	if feeSeparator < 0 {
		panic(lo.ErrInvalidPoolPath)
	}
	return order.InputMint().String() + ":" + order.OutputMint().String() + poolPath[feeSeparator:]
}

func getPool(token0Path, token1Path string, fee uint32) *pl.Pool {
	value := pl.GetPools().Get(pl.GetPoolPath(token0Path, token1Path, fee))
	pool, ok := value.(*pl.Pool)
	if !ok || pool == nil {
		return nil
	}
	return pool
}

func safeConvertToInt64(value *u256.Uint) int64 {
	maxInt64 := u256.NewUint(9223372036854775807) // 2^63 - 1
	if value.Gt(maxInt64) {
		panic(ufmt.Sprintf("value %s exceeds int64 max", value.ToString()))
	}
	return int64(value.Uint64())
}
