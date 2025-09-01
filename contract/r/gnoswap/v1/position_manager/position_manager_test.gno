package position_manager

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestMint(t *testing.T) {
	// Setup
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	params := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	// Test mint
	tokenId, liquidity, amount0, amount1 := Mint(params)

	// Verify
	if tokenId == 0 {
		t.Fatal("expected valid token ID")
	}
	if liquidity == "" {
		t.Fatal("expected non-zero liquidity")
	}

	// Check position exists
	position := positions[tokenId]
	if position == nil {
		t.Fatal("position should exist")
	}
	if position.tickLower != params.tickLower {
		t.Fatalf("expected tickLower %d, got %d", params.tickLower, position.tickLower)
	}
	if position.tickUpper != params.tickUpper {
		t.Fatalf("expected tickUpper %d, got %d", params.tickUpper, position.tickUpper)
	}
}

func TestIncreaseLiquidity(t *testing.T) {
	// Setup - create initial position
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	mintParams := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	tokenId, initialLiquidity, _, _ := Mint(mintParams)

	// Test increase liquidity
	increaseParams := IncreaseLiquidityParams{
		tokenId:        tokenId,
		amount0Desired: "500000",
		amount1Desired: "500000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
	}

	additionalLiquidity, amount0, amount1 := IncreaseLiquidity(increaseParams)

	// Verify
	if additionalLiquidity == "" {
		t.Fatal("expected non-zero additional liquidity")
	}

	position := positions[tokenId]
	initialLiq := u256.MustFromDecimal(initialLiquidity)
	additionalLiq := u256.MustFromDecimal(additionalLiquidity)
	expectedTotal := new(u256.Uint).Add(initialLiq, additionalLiq)

	if !position.liquidity.Eq(expectedTotal) {
		t.Fatalf("expected total liquidity %s, got %s",
			expectedTotal.ToString(), position.liquidity.ToString())
	}
}

func TestDecreaseLiquidity(t *testing.T) {
	// Setup - create initial position
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	mintParams := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	tokenId, initialLiquidity, _, _ := Mint(mintParams)

	// Test decrease liquidity (remove half)
	initialLiq := u256.MustFromDecimal(initialLiquidity)
	halfLiquidity := new(u256.Uint).Div(initialLiq, u256.NewUint(2))

	decreaseParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  halfLiquidity.ToString(),
		amount0Min: "0",
		amount1Min: "0",
		deadline:   time.Now().Unix() + 3600,
	}

	amount0, amount1 := DecreaseLiquidity(decreaseParams)

	// Verify
	position := positions[tokenId]
	expectedRemaining := new(u256.Uint).Sub(initialLiq, halfLiquidity)

	if !position.liquidity.Eq(expectedRemaining) {
		t.Fatalf("expected remaining liquidity %s, got %s",
			expectedRemaining.ToString(), position.liquidity.ToString())
	}

	// Tokens owed should be updated
	if position.tokensOwed0.IsZero() && position.tokensOwed1.IsZero() {
		t.Fatal("expected non-zero tokens owed after decrease")
	}
}

func TestCollect(t *testing.T) {
	// Setup - create position and decrease liquidity to generate fees
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	mintParams := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	tokenId, liquidity, _, _ := Mint(mintParams)

	// Decrease to generate tokens owed
	decreaseParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  liquidity,
		amount0Min: "0",
		amount1Min: "0",
		deadline:   time.Now().Unix() + 3600,
	}
	DecreaseLiquidity(decreaseParams)

	// Test collect
	collectParams := CollectParams{
		tokenId:    tokenId,
		recipient:  user,
		amount0Max: u256.MaxUint256().ToString(),
		amount1Max: u256.MaxUint256().ToString(),
	}

	amount0Collected, amount1Collected := Collect(collectParams)

	// Verify
	position := positions[tokenId]
	if !position.tokensOwed0.IsZero() || !position.tokensOwed1.IsZero() {
		t.Fatal("expected tokens owed to be zero after collect")
	}
}

func TestBurn(t *testing.T) {
	// Setup - create position and clear it
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	mintParams := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	tokenId, liquidity, _, _ := Mint(mintParams)

	// Remove all liquidity
	decreaseParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  liquidity,
		amount0Min: "0",
		amount1Min: "0",
		deadline:   time.Now().Unix() + 3600,
	}
	DecreaseLiquidity(decreaseParams)

	// Collect all fees
	collectParams := CollectParams{
		tokenId:    tokenId,
		recipient:  user,
		amount0Max: u256.MaxUint256().ToString(),
		amount1Max: u256.MaxUint256().ToString(),
	}
	Collect(collectParams)

	// Test burn
	Burn(tokenId)

	// Verify position is deleted
	if positions[tokenId] != nil {
		t.Fatal("position should be deleted after burn")
	}
}

func TestPositions(t *testing.T) {
	// Setup
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	params := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user,
	}

	tokenId, liquidity, _, _ := Mint(params)

	// Test Positions getter
	nonce, operator, token0, token1, fee, tickLower, tickUpper,
		liquidityStr, feeGrowth0, feeGrowth1, tokensOwed0, tokensOwed1 := Positions(tokenId)

	// Verify
	if token0 != params.token0 {
		t.Fatalf("expected token0 %s, got %s", params.token0, token0)
	}
	if token1 != params.token1 {
		t.Fatalf("expected token1 %s, got %s", params.token1, token1)
	}
	if fee != params.fee {
		t.Fatalf("expected fee %d, got %d", params.fee, fee)
	}
	if tickLower != params.tickLower {
		t.Fatalf("expected tickLower %d, got %d", params.tickLower, tickLower)
	}
	if tickUpper != params.tickUpper {
		t.Fatalf("expected tickUpper %d, got %d", params.tickUpper, tickUpper)
	}
	if liquidityStr != liquidity {
		t.Fatalf("expected liquidity %s, got %s", liquidity, liquidityStr)
	}
}

func TestDeadlineValidation(t *testing.T) {
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user := std.GetPrevAddr()

	// Test with expired deadline
	params := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() - 3600, // expired
		recipient:      user,
	}

	// Should panic with expired transaction error
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic for expired deadline")
		} else if r != errTransactionExpired {
			t.Fatalf("expected errTransactionExpired, got %v", r)
		}
	}()

	Mint(params)
}

func TestUnauthorizedAccess(t *testing.T) {
	// Create position as user1
	std.TestSetPrevRealm(testutils.NewUserRealm())
	user1 := std.GetPrevAddr()

	params := MintParams{
		token0:         "gno.land/r/test/token0",
		token1:         "gno.land/r/test/token1",
		fee:            3000,
		tickLower:      -887220,
		tickUpper:      887220,
		amount0Desired: "1000000",
		amount1Desired: "1000000",
		amount0Min:     "0",
		amount1Min:     "0",
		deadline:       time.Now().Unix() + 3600,
		recipient:      user1,
	}

	tokenId, _, _, _ := Mint(params)

	// Try to decrease liquidity as different user
	std.TestSetPrevAddr(testutils.TestAddress("unauthorized"))

	decreaseParams := DecreaseLiquidityParams{
		tokenId:    tokenId,
		liquidity:  "100",
		amount0Min: "0",
		amount1Min: "0",
		deadline:   time.Now().Unix() + 3600,
	}

	// Should panic with not authorized error
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic for unauthorized access")
		} else if r != errNotAuthorized {
			t.Fatalf("expected errNotAuthorized, got %v", r)
		}
	}()

	DecreaseLiquidity(decreaseParams)
}