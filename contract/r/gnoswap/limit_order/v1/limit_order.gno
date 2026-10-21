package v1

import (
	"chain"
	"strconv"
	"strings"
	"time"

	prbac "gno.land/p/gnoswap/rbac/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	lo "gno.land/r/gnoswap/limit_order"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"
)

// CreateOrder escrows input and records a new limit order.
func (l *limitOrderV1) CreateOrder(
	_ int,
	rlm realm,
	poolPath string,
	inputMint address,
	outputMint address,
	makingAmount uint64,
	takingAmount uint64,
	slippageBps uint64,
	expiredAt int64,
) uint64 {
	access.AssertIsRlmCurrent(0, rlm)
	l.acquireLock(0, rlm)
	defer l.releaseLock(0, rlm)
	common.AssertIsNotHandleNativeCoin()

	owner := rlm.Previous().Address()
	l.validateCreateOrder(
		poolPath,
		inputMint,
		outputMint,
		makingAmount,
		takingAmount,
		slippageBps,
		expiredAt,
	)
	feeRecipient := access.MustGetAddress(prbac.ROLE_DEVOPS.String())
	orderId := l.store.GetOrderNextID()
	if orderId == ^uint64(0) {
		panic(lo.ErrAmountOverflow)
	}

	order := lo.NewLimitOrder(
		orderId,
		owner,
		poolPath,
		inputMint,
		outputMint,
		u256.NewUint(makingAmount),
		u256.NewUint(takingAmount),
		slippageBps,
		feeRecipient,
		expiredAt,
	)

	mustStore(l.store.SetOrderNextID(0, rlm, orderId+1))
	mustStore(l.store.SetOrder(0, rlm, orderId, *order))
	mustStore(l.store.AddOwnerOrder(0, rlm, owner, orderId))

	common.SafeGRC20TransferFrom(
		0,
		rlm,
		inputMint.String(),
		owner,
		l.contractAddr,
		safeConvertToInt64(u256.NewUint(makingAmount)),
	)

	chain.Emit(
		"OrderCreated",
		"owner", owner.String(),
		"orderId", strconv.FormatUint(orderId, 10),
		"poolPath", poolPath,
		"inputMint", inputMint.String(),
		"outputMint", outputMint.String(),
		"makingAmount", strconv.FormatUint(makingAmount, 10),
		"takingAmount", strconv.FormatUint(takingAmount, 10),
		"slippageBps", strconv.FormatUint(slippageBps, 10),
		"expiredAt", strconv.FormatInt(expiredAt, 10),
		"feeBps", strconv.FormatUint(order.FeeBps(), 10),
		"feeRecipient", feeRecipient.String(),
	)

	return orderId
}

// ExecuteOrder partially or fully fills an order using an exact input amount.
// The Router-net output is paid to the owner and snapshotted fee recipient.
func (l *limitOrderV1) ExecuteOrder(
	_ int,
	rlm realm,
	orderId uint64,
	amountIn uint64,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)
	l.acquireLock(0, rlm)
	defer l.releaseLock(0, rlm)
	common.AssertIsNotHandleNativeCoin()

	order, exists := l.store.GetOrder(orderId)
	if !exists {
		panic(lo.ErrOrderNotFound)
	}
	l.validateExecuteOrder(&order, amountIn)

	amountInU256 := u256.NewUint(amountIn)
	minOutput := order.GetMinimumOutput(amountInU256)
	safeConvertToInt64(minOutput)
	amountInInt := safeConvertToInt64(amountInU256)
	inputBalanceBefore := common.BalanceOf(order.InputMint().String(), l.contractAddr)
	outputBalanceBefore := common.BalanceOf(order.OutputMint().String(), l.contractAddr)

	routerAddr := chain.PackageAddress("gno.land/r/gnoswap/router")
	common.SafeGRC20Approve(0, rlm, order.InputMint().String(), routerAddr, amountInInt)
	deadline := time.Now().Unix() + 300
	routePath := buildOrderRoutePath(&order)
	actualInputString, routerOutputString := router.ExactInSingleSwapRoute(
		cross(rlm),
		order.InputMint().String(),
		order.OutputMint().String(),
		strconv.FormatUint(amountIn, 10),
		routePath,
		minOutput.ToString(),
		"0",
		deadline,
		"",
	)
	common.SafeGRC20Approve(0, rlm, order.InputMint().String(), routerAddr, 0)

	actualInput := parseRouterAmount(actualInputString)
	routerOutput := parseRouterAmount(routerOutputString)
	if actualInput != amountIn {
		panic(lo.ErrInvalidFillAmount)
	}

	inputBalanceAfter := common.BalanceOf(order.InputMint().String(), l.contractAddr)
	outputBalanceAfter := common.BalanceOf(order.OutputMint().String(), l.contractAddr)
	if inputBalanceBefore < 0 || inputBalanceAfter < 0 ||
		inputBalanceAfter > inputBalanceBefore ||
		uint64(inputBalanceBefore-inputBalanceAfter) != actualInput {
		panic(lo.ErrInvalidFillAmount)
	}
	if outputBalanceBefore < 0 || outputBalanceAfter < 0 ||
		outputBalanceAfter < outputBalanceBefore ||
		uint64(outputBalanceAfter-outputBalanceBefore) != routerOutput {
		panic(lo.ErrInsufficientOutput)
	}

	feeBefore := u256.Zero().Set(order.ExecutionFee())
	routerOutputU256 := u256.NewUint(routerOutput)
	order.ApplyFill(amountInU256, routerOutputU256)
	incrementalFee := u256.Zero().Sub(order.ExecutionFee(), feeBefore)
	userOutput := u256.Zero().Sub(routerOutputU256, incrementalFee)

	// Persist accounting before the token transfers, while the global lock is held.
	mustStore(l.store.SetOrder(0, rlm, orderId, order))
	if !userOutput.IsZero() {
		common.SafeGRC20Transfer(
			0,
			rlm,
			order.OutputMint().String(),
			order.Owner(),
			safeConvertToInt64(userOutput),
		)
	}
	if !incrementalFee.IsZero() {
		common.SafeGRC20Transfer(
			0,
			rlm,
			order.OutputMint().String(),
			order.FeeRecipient(),
			safeConvertToInt64(incrementalFee),
		)
	}

	chain.Emit(
		"OrderFilled",
		"owner", order.Owner().String(),
		"orderId", strconv.FormatUint(orderId, 10),
		"amountIn", strconv.FormatUint(actualInput, 10),
		"routerNetOutput", strconv.FormatUint(routerOutput, 10),
		"userOutput", userOutput.ToString(),
		"executionFee", incrementalFee.ToString(),
		"filledInput", order.FilledInput().ToString(),
		"remainingInput", order.RemainingInput().ToString(),
		"grossOutput", order.GrossOutput().ToString(),
		"cumulativeExecutionFee", order.ExecutionFee().ToString(),
	)
	if order.Status() == lo.OrderStatusExecuted {
		chain.Emit(
			"OrderCompleted",
			"owner", order.Owner().String(),
			"orderId", strconv.FormatUint(orderId, 10),
			"filledInput", order.FilledInput().ToString(),
			"grossOutput", order.GrossOutput().ToString(),
			"cumulativeExecutionFee", order.ExecutionFee().ToString(),
		)
	}

	return actualInputString, routerOutputString
}

// CancelOrder cancels an active order and refunds its remaining input.
func (l *limitOrderV1) CancelOrder(_ int, rlm realm, orderId uint64) {
	access.AssertIsRlmCurrent(0, rlm)
	l.acquireLock(0, rlm)
	defer l.releaseLock(0, rlm)
	common.AssertIsNotHandleNativeCoin()

	owner := rlm.Previous().Address()
	order, exists := l.store.GetOrder(orderId)
	if !exists {
		panic(lo.ErrOrderNotFound)
	}
	if order.Owner() != owner {
		panic(lo.ErrUnauthorized)
	}
	validateCanCancel(&order)

	refund := order.RefundInput()
	expired := order.IsExpired()
	if expired {
		order.SetStatus(lo.OrderStatusExpired)
	} else {
		order.SetStatus(lo.OrderStatusCancelled)
	}
	mustStore(l.store.SetOrder(0, rlm, orderId, order))
	if !refund.IsZero() {
		common.SafeGRC20Transfer(
			0,
			rlm,
			order.InputMint().String(),
			order.Owner(),
			safeConvertToInt64(refund),
		)
	}

	eventName := "OrderCancelled"
	if expired {
		eventName = "OrderExpired"
	}
	chain.Emit(
		eventName,
		"owner", order.Owner().String(),
		"orderId", strconv.FormatUint(orderId, 10),
		"refundedInput", refund.ToString(),
		"filledInput", order.FilledInput().ToString(),
		"grossOutput", order.GrossOutput().ToString(),
		"executionFee", order.ExecutionFee().ToString(),
	)
}

// CleanupExpiredOrders expires and refunds at most maxCount expired active orders.
func (l *limitOrderV1) CleanupExpiredOrders(_ int, rlm realm, maxCount uint64) uint64 {
	access.AssertIsRlmCurrent(0, rlm)
	l.acquireLock(0, rlm)
	defer l.releaseLock(0, rlm)
	common.AssertIsNotHandleNativeCoin()

	if maxCount > lo.MAX_QUERY_LIMIT {
		maxCount = lo.MAX_QUERY_LIMIT
	}
	if maxCount == 0 {
		return 0
	}

	currentTime := time.Now().Unix()
	orders := l.store.GetOrders()
	var expiredOrderIDs []uint64
	orders.Iterate("", "", func(_ string, value interface{}) bool {
		if uint64(len(expiredOrderIDs)) >= maxCount {
			return true
		}
		order := value.(lo.LimitOrder)
		if order.Status() == lo.OrderStatusActive && currentTime >= order.ExpiredAt() {
			expiredOrderIDs = append(expiredOrderIDs, order.ID())
		}
		return false
	})

	cleaned := uint64(0)
	for _, orderId := range expiredOrderIDs {
		order, exists := l.store.GetOrder(orderId)
		if !exists || order.Status() != lo.OrderStatusActive || currentTime < order.ExpiredAt() {
			continue
		}

		refund := order.RefundInput()
		order.SetStatus(lo.OrderStatusExpired)
		mustStore(l.store.SetOrder(0, rlm, orderId, order))
		if !refund.IsZero() {
			common.SafeGRC20Transfer(
				0,
				rlm,
				order.InputMint().String(),
				order.Owner(),
				safeConvertToInt64(refund),
			)
		}
		chain.Emit(
			"OrderExpired",
			"owner", order.Owner().String(),
			"orderId", strconv.FormatUint(orderId, 10),
			"refundedInput", refund.ToString(),
			"filledInput", order.FilledInput().ToString(),
			"grossOutput", order.GrossOutput().ToString(),
			"executionFee", order.ExecutionFee().ToString(),
		)
		cleaned++
	}

	return cleaned
}

func (l *limitOrderV1) acquireLock(_ int, rlm realm) {
	if l.store.IsLocked() {
		panic(lo.ErrLocked)
	}
	mustStore(l.store.SetLocked(0, rlm, true))
}

func (l *limitOrderV1) releaseLock(_ int, rlm realm) {
	mustStore(l.store.SetLocked(0, rlm, false))
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
	if makingAmount > lo.MAX_TOKEN_AMOUNT || takingAmount > lo.MAX_TOKEN_AMOUNT {
		panic(lo.ErrAmountOverflow)
	}
	if slippageBps > 1000 {
		panic(lo.ErrInvalidSlippage)
	}

	l.validatePoolAndTokens(poolPath, inputMint, outputMint)

	currentTime := time.Now().Unix()
	if expiredAt <= currentTime {
		panic(lo.ErrDeadlineTooShort)
	}
	duration := expiredAt - currentTime
	if duration < lo.MIN_ORDER_DEADLINE {
		panic(lo.ErrDeadlineTooShort)
	}
	if duration > lo.MAX_ORDER_DEADLINE {
		panic(lo.ErrDeadlineTooLong)
	}
}

func (l *limitOrderV1) validateExecuteOrder(order *lo.LimitOrder, amountIn uint64) {
	if order.Status() != lo.OrderStatusActive {
		panic(lo.ErrOrderNotActive)
	}
	if order.IsExpired() {
		panic(lo.ErrOrderExpired)
	}
	if amountIn == 0 || amountIn > lo.MAX_TOKEN_AMOUNT {
		if amountIn > lo.MAX_TOKEN_AMOUNT {
			panic(lo.ErrAmountOverflow)
		}
		panic(lo.ErrInvalidFillAmount)
	}
	if u256.NewUint(amountIn).Gt(order.RemainingInput()) {
		panic(lo.ErrInvalidFillAmount)
	}
}

func validateCanCancel(order *lo.LimitOrder) {
	switch order.Status() {
	case lo.OrderStatusActive:
		return
	case lo.OrderStatusExecuted:
		panic(lo.ErrAlreadyExecuted)
	case lo.OrderStatusCancelled:
		panic(lo.ErrAlreadyCancelled)
	case lo.OrderStatusExpired:
		panic(lo.ErrOrderExpired)
	default:
		panic(lo.ErrOrderNotActive)
	}
}

// validatePoolAndTokens requires the supplied pool ID to be canonical and
// verifies that the requested tokens form one directed edge of that pool.
func (l *limitOrderV1) validatePoolAndTokens(poolPath string, inputMint, outputMint address) {
	parts := strings.Split(poolPath, ":")
	if len(parts) != 3 || parts[0] == "" || parts[1] == "" || parts[0] == parts[1] {
		panic(lo.ErrInvalidPoolPath)
	}
	feeValue, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		panic(lo.ErrInvalidPoolPath)
	}
	fee := uint32(feeValue)
	if pl.GetPoolPath(parts[0], parts[1], fee) != poolPath {
		panic(lo.ErrInvalidPoolPath)
	}

	pool := getPool(parts[0], parts[1], fee)
	if pool == nil {
		panic(lo.ErrPoolNotFound)
	}
	if pool.PoolPath() != poolPath || pool.Token0Path() != parts[0] || pool.Token1Path() != parts[1] {
		panic(lo.ErrInvalidPoolPath)
	}

	token0Path := pool.Token0Path()
	token1Path := pool.Token1Path()
	inputPath := inputMint.String()
	outputPath := outputMint.String()
	forward := inputPath == token0Path && outputPath == token1Path
	reverse := inputPath == token1Path && outputPath == token0Path
	if !forward && !reverse {
		panic(lo.ErrTokenPoolMismatch)
	}
}

// buildOrderRoutePath reverses the canonical pool token order when necessary
// so the Router receives a route directed from the order's input to its output.
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

func parseRouterAmount(value string) uint64 {
	amount, err := strconv.ParseUint(value, 10, 64)
	if err != nil {
		panic(lo.ErrInvalidFillAmount)
	}
	if amount > lo.MAX_TOKEN_AMOUNT {
		panic(lo.ErrAmountOverflow)
	}
	return amount
}

func safeConvertToInt64(value *u256.Uint) int64 {
	if value.Gt(u256.NewUint(lo.MAX_TOKEN_AMOUNT)) {
		panic(lo.ErrAmountOverflow)
	}
	return int64(value.Uint64())
}
