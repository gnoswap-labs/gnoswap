package v1

import (
	"strconv"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

// mockMultiSwapExecutor implements MultiSwapExecutor with predetermined results.
// Each successive call to Run returns the next result in the sequence.
type mockMultiSwapExecutor struct {
	results []mockSwapResult
	callIdx int
}

type mockSwapResult struct {
	amountIn  int64
	amountOut int64
}

func (m *mockMultiSwapExecutor) Run(_ SwapParams, _ SwapCallbackData, _ address) (int64, int64) {
	if m.callIdx >= len(m.results) {
		panic("mockMultiSwapExecutor: unexpected extra call")
	}
	r := m.results[m.callIdx]
	m.callIdx++
	return r.amountIn, r.amountOut
}

// TestProcessBackwardDrySwap_TwoHop verifies that processBackwardDrySwap
// returns the final pool's output (amountOut) for a 2-hop ExactOut swap,
// not the intermediate pool's output.
//
// Scenario: ExactOut A→B→C, user requests 100 C.
//
// Backward processing order:
//
//	Iteration 1 — pool[1] (B→C): amountIn=50 (B needed), amountOut=100 (C produced)
//	Iteration 2 — pool[0] (A→B): amountIn=25 (A needed), amountOut=50  (B produced)
//
// Expected return: (firstAmountIn=25, lastAmountOut=100)
//
//   - firstAmountIn = 25  → total A the user must supply
//   - lastAmountOut = 100 → total C the user receives (from pool[1])
//
// Bug: the function currently returns (25, 50) because it returns the
// amountOut from the *last iteration* (pool[0], intermediate B) instead
// of capturing the amountOut from the *first iteration* (pool[1], final C).
func TestProcessBackwardDrySwap_TwoHop(t *testing.T) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	mock := &mockMultiSwapExecutor{
		results: []mockSwapResult{
			{amountIn: 50, amountOut: 100}, // iter 1: pool[1] B→C
			{amountIn: 25, amountOut: 50},  // iter 2: pool[0] A→B
		},
	}

	processor := &MultiSwapProcessor{
		executor:   mock,
		direction:  Backward,
		router:     nil, // not used by mock executor
		isSimulate: true,
	}

	// 2-hop path: pool[0]=A→B, pool[1]=B→C
	swapPath := "tokenA:tokenB:3000*POOL*tokenB:tokenC:3000"

	// Initial params point to the last pool (B→C) for backward processing
	sp := SwapParams{
		SingleSwapParams: SingleSwapParams{
			tokenIn:         "tokenB",
			tokenOut:        "tokenC",
			fee:             3000,
			amountSpecified: -100, // ExactOut: want 100 C
		},
		recipient: routerAddr,
	}

	firstAmountIn, amountOut, err := processor.processBackwardDrySwap(sp, 2, swapPath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// firstAmountIn should be the A input from pool[0]
	uassert.Equal(t,
		strconv.FormatInt(firstAmountIn, 10),
		"25",
	)

	// amountOut must be the final C output (100), not the intermediate B output (50).
	uassert.Equal(t,
		strconv.FormatInt(amountOut, 10),
		"100",
	)
}

// TestProcessBackwardDrySwap_ThreeHop verifies the same issue with 3-hop paths.
//
// Scenario: ExactOut A→B→C→D, user requests 200 D.
//
// Backward processing order:
//
//	Iteration 1 — pool[2] (C→D): amountIn=120 (C), amountOut=200 (D)  ← final output
//	Iteration 2 — pool[1] (B→C): amountIn=60  (B), amountOut=120 (C) ← intermediate
//	Iteration 3 — pool[0] (A→B): amountIn=30  (A), amountOut=60  (B) ← intermediate
//
// Expected return: (firstAmountIn=30, lastAmountOut=200)
// Bug return:      (firstAmountIn=30, lastAmountOut=60)  ← pool[0]'s B output
func TestProcessBackwardDrySwap_ThreeHop(t *testing.T) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	mock := &mockMultiSwapExecutor{
		results: []mockSwapResult{
			{amountIn: 120, amountOut: 200}, // iter 1: pool[2] C→D
			{amountIn: 60, amountOut: 120},  // iter 2: pool[1] B→C
			{amountIn: 30, amountOut: 60},   // iter 3: pool[0] A→B
		},
	}

	processor := &MultiSwapProcessor{
		executor:   mock,
		direction:  Backward,
		router:     nil,
		isSimulate: true,
	}

	// 3-hop path
	swapPath := "tokenA:tokenB:3000*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:3000"

	sp := SwapParams{
		SingleSwapParams: SingleSwapParams{
			tokenIn:         "tokenC",
			tokenOut:        "tokenD",
			fee:             3000,
			amountSpecified: -200, // ExactOut: want 200 D
		},
		recipient: routerAddr,
	}

	firstAmountIn, amountOut, err := processor.processBackwardDrySwap(sp, 3, swapPath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	uassert.Equal(t,
		strconv.FormatInt(firstAmountIn, 10),
		"30",
	)

	// amountOut must be 200 (final D output), not 60 (pool[0] intermediate B output).
	uassert.Equal(t,
		strconv.FormatInt(amountOut, 10),
		"200",
	)
}

// TestProcessBackwardDrySwap_SinglePool verifies that with a single pool,
// the function trivially returns the correct values (no multi-hop ambiguity).
func TestProcessBackwardDrySwap_SinglePool(t *testing.T) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	mock := &mockMultiSwapExecutor{
		results: []mockSwapResult{
			{amountIn: 50, amountOut: 100}, // single pool A→B
		},
	}

	processor := &MultiSwapProcessor{
		executor:   mock,
		direction:  Backward,
		router:     nil,
		isSimulate: true,
	}

	swapPath := "tokenA:tokenB:3000"

	sp := SwapParams{
		SingleSwapParams: SingleSwapParams{
			tokenIn:         "tokenA",
			tokenOut:        "tokenB",
			fee:             3000,
			amountSpecified: -100,
		},
		recipient: routerAddr,
	}

	firstAmountIn, amountOut, err := processor.processBackwardDrySwap(sp, 1, swapPath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	uassert.Equal(t,
		strconv.FormatInt(firstAmountIn, 10),
		"50",
	)

	// With a single pool, there's no ambiguity — amountOut is the only output.
	uassert.Equal(t,
		strconv.FormatInt(amountOut, 10),
		"100",
	)
}
