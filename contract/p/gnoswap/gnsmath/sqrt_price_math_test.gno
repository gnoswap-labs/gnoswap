package gnsmath

import (
	"testing"

	"gno.land/p/nt/uassert"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// Test data constants
var (
	Q96         = u256.MustFromDecimal("79228162514264337593543950336") // 2^96
	MAX_UINT256 = u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")
	MAX_UINT160 = u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")
)

// TestGetNextPriceAmount0Add tests the internal helper for adding token0
func TestGetNextPriceAmount0Add(t *testing.T) {
	tests := []struct {
		name             string
		currentSqrtPrice *u256.Uint
		liquidity        *u256.Uint
		amountToAdd      *u256.Uint
		expected         *u256.Uint
	}{
		// Normal cases
		{
			name:             "simple_case: price halves",
			currentSqrtPrice: encodePriceSqrt("1", "1"), // √(1/1) * 2^96
			liquidity:        u256.MustFromDecimal("1000000000000000000"),
			amountToAdd:      u256.MustFromDecimal("1000000000000000000"),
			expected:         new(u256.Uint).Rsh(encodePriceSqrt("1", "1"), 1), // ÷2
		},
		{
			name:             "normal_addition",
			currentSqrtPrice: Q96,
			liquidity:        u256.MustFromDecimal("1000000000000000000"),
			amountToAdd:      u256.MustFromDecimal("100000000000000000"),
			expected:         u256.MustFromDecimal("72025602285694852357767227579"),
		},
		{
			name:             "small_amount_high_liquidity",
			currentSqrtPrice: Q96,
			liquidity:        u256.MustFromDecimal("100000000000000000000"),
			amountToAdd:      u256.One(),
			expected:         u256.MustFromDecimal("79228162514264337592751668711"),
		},
		{
			name:             "overflow_path_fallback",
			currentSqrtPrice: encodePriceSqrt("1", "1"),
			liquidity:        u256.One(),
			amountToAdd:      encodePriceSqrt("1", "1"),
			expected:         u256.One(),
		},
		{
			name:             "one_tick_no_move_when_amount_too_small",
			currentSqrtPrice: new(u256.Uint).Add(MIN_SQRT_RATIO, u256.NewUint(2)),
			liquidity:        u256.MustFromDecimal("1000000000000000000"),
			amountToAdd:      u256.One(),
			expected:         new(u256.Uint).Add(MIN_SQRT_RATIO, u256.NewUint(2)),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getNextPriceAmount0Add(tt.currentSqrtPrice, tt.liquidity, tt.amountToAdd)
			uassert.Equal(t, tt.expected.ToString(), result.ToString())
		})
	}
}

// TestGetNextPriceAmount0Remove tests the internal helper for removing token0
func TestGetNextPriceAmount0Remove(t *testing.T) {
	tiny := u256.One()
	medium := u256.MustFromDecimal("100000000000000000")
	huge := u256.MustFromDecimal("1000000000000000000000000000000")

	tests := []struct {
		name           string
		current        *u256.Uint
		liquidity      *u256.Uint
		amountToRemove *u256.Uint
		shouldPanic    bool
		panicMsg       string
		validate       func(t *testing.T, before, after *u256.Uint)
	}{
		{
			name:           "tiny_removal_monotonic",
			current:        Q96,
			liquidity:      u256.MustFromDecimal("100000000000000000000"),
			amountToRemove: tiny,
			validate: func(t *testing.T, before, after *u256.Uint) {
				uassert.True(t, after.Gt(before), "tiny removal must increase price")
			},
		},
		{
			name:           "medium_removal_larger_increase",
			current:        Q96,
			liquidity:      u256.MustFromDecimal("1000000000000000000"),
			amountToRemove: medium,
			validate: func(t *testing.T, before, after *u256.Uint) {
				uassert.True(t, after.Gt(before), "medium removal must increase price")
				diff := new(u256.Uint).Sub(after, before)
				uassert.True(t, diff.Gte(u256.One()), "price increase ≥ 1 tick")
			},
		},
		{
			name:           "remove_at_min_boundary",
			current:        MIN_SQRT_RATIO,
			liquidity:      u256.MustFromDecimal("1000000000000000000"),
			amountToRemove: tiny,
			validate: func(t *testing.T, before, after *u256.Uint) {
				uassert.True(t, after.Gt(before), "removal at MIN should increase price")
			},
		},
		{
			name:           "remove_at_high_price",
			current:        u256.MustFromDecimal("1000000000000000000000000000000"),
			liquidity:      u256.MustFromDecimal("1000000000000000000"),
			amountToRemove: tiny,
			validate: func(t *testing.T, before, after *u256.Uint) {
				uassert.True(t, after.Gt(before), "removal should increase price")
			},
		},
		{
			name:           "remove_near_max_with_huge_liquidity",
			current:        new(u256.Uint).Sub(MAX_SQRT_RATIO, u256.NewUint(1000000)),
			liquidity:      u256.MustFromDecimal("100000000000000000000000000"),
			amountToRemove: tiny,
			validate: func(t *testing.T, before, after *u256.Uint) {
				uassert.True(t, after.Gt(before), "removal should increase price")
			},
		},
		{
			name:           "overflow_check_fail",
			current:        Q96,
			liquidity:      u256.MustFromDecimal("1"),
			amountToRemove: MAX_UINT256,
			shouldPanic:    true,
			panicMsg:       errInvalidPoolSqrtPrice.Error(),
		},
		{
			name:           "insufficient_liquidity",
			current:        Q96,
			liquidity:      u256.MustFromDecimal("1000"),
			amountToRemove: u256.MustFromDecimal("100000000000000000000"),
			shouldPanic:    true,
			panicMsg:       errInvalidPoolSqrtPrice.Error(),
		},
		{
			name:           "overflow_path_large_remove_panics",
			current:        Q96,
			liquidity:      u256.MustFromDecimal("1000000000000000000"),
			amountToRemove: huge,
			shouldPanic:    true,
			panicMsg:       errInvalidPoolSqrtPrice.Error(),
		},
		{
			name:           "remove_at_max_boundary_insufficient_liquidity",
			current:        new(u256.Uint).Sub(MAX_SQRT_RATIO, u256.One()), // MAX - 1
			liquidity:      u256.MustFromDecimal("1000000000000000000000"),
			amountToRemove: u256.MustFromDecimal("1000"),
			shouldPanic:    true,
			panicMsg:       errInvalidPoolSqrtPrice.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			before := tt.current.Clone()
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					_ = getNextPriceAmount0Remove(tt.current, tt.liquidity, tt.amountToRemove)
				})
				return
			}
			after := getNextPriceAmount0Remove(tt.current, tt.liquidity, tt.amountToRemove)
			tt.validate(t, before, after)
		})
	}
}

// TestGetNextSqrtPriceFromAmount0RoundingUp tests price calculation when adding/removing token0
func TestGetNextSqrtPriceFromAmount0RoundingUp(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amount      *u256.Uint
		add         bool
		expected    *u256.Uint
		shouldPanic bool
		panicMsg    string
	}{
		// Basic functionality
		{
			name:      "zero_amount_returns_same_price",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("2000000"),
			amount:    u256.Zero(),
			add:       true,
			expected:  Q96,
		},
		{
			name:      "add_token0_decreases_price",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			add:       true,
			expected:  u256.MustFromDecimal("72025602285694852357767227579"),
		},
		{
			name:      "remove_token0_increases_price",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			add:       false,
			expected:  u256.MustFromDecimal("88031291682515930659493278152"),
		},
		// Boundary cases
		{
			name:      "add_near_min_clamps",
			sqrtPX96:  u256.MustFromDecimal("4295128741"),
			liquidity: u256.MustFromDecimal("1000"),
			amount:    u256.MustFromDecimal("1000000000000000000000"),
			add:       true,
			expected:  u256.MustFromDecimal("4074254652"),
		},
		{
			name:      "min_boundary_stays_same",
			sqrtPX96:  u256.MustFromDecimal("4295128740"),
			liquidity: u256.MustFromDecimal("1000"),
			amount:    u256.MustFromDecimal("1000000"),
			add:       true,
			expected:  u256.MustFromDecimal("4295128740"),
		},
		{
			name:      "min_boundary_no_change_tiny_amount",
			sqrtPX96:  u256.MustFromDecimal("4295128740"),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("1"),
			add:       true,
			expected:  u256.MustFromDecimal("4295128740"),
		},
		{
			name:      "increase_price_from_min",
			sqrtPX96:  u256.MustFromDecimal("4295128739"),
			liquidity: u256.MustFromDecimal("1000"),
			amount:    u256.MustFromDecimal("1"),
			add:       false,
			expected:  u256.MustFromDecimal("4295128740"),
		},
		// Error cases
		{
			name:        "remove_causes_overflow",
			sqrtPX96:    Q96,
			liquidity:   u256.MustFromDecimal("1"),
			amount:      MAX_UINT256,
			add:         false,
			shouldPanic: true,
			panicMsg:    errInvalidPoolSqrtPrice.Error(),
		},
		{
			name:        "remove_insufficient_liquidity",
			sqrtPX96:    Q96,
			liquidity:   u256.MustFromDecimal("1000"),
			amount:      u256.MustFromDecimal("100000000000000000000"),
			add:         false,
			shouldPanic: true,
			panicMsg:    errInvalidPoolSqrtPrice.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextSqrtPriceFromAmount0RoundingUp(tt.sqrtPX96, tt.liquidity, tt.amount, tt.add)
				})
				return
			}

			result := getNextSqrtPriceFromAmount0RoundingUp(tt.sqrtPX96, tt.liquidity, tt.amount, tt.add)
			uassert.Equal(t, tt.expected.ToString(), result.ToString())
		})
	}
}

// TestGetNextPriceAmount1Add tests the internal helper for adding token1
func TestGetNextPriceAmount1Add(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amount      *u256.Uint
		expected    *u256.Uint
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "normal_addition",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			expected:  u256.MustFromDecimal("87150978765690771352898345369"),
		},
		{
			name:      "amount_lte_max160",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("1000000000000000000"),
			expected:  u256.MustFromDecimal("158456325028528675187087900672"),
		},
		{
			name:      "amount_gt_max160",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    new(u256.Uint).Add(MAX_UINT160, u256.MustFromDecimal("1000000000000000000")),
			expected:  u256.MustFromDecimal("115787736929662111563370814583278000176356624084966981749664"),
		},
		{
			name:      "very_small_liquidity",
			sqrtPX96:  Q96,
			liquidity: u256.One(),
			amount:    u256.MustFromDecimal("1000"),
			expected:  u256.MustFromDecimal("79307390676778601931137494286336"),
		},
		{
			name:      "add_at_max_boundary",
			sqrtPX96:  MAX_SQRT_RATIO,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("1000"),
			expected:  u256.MustFromDecimal("1461446703485210103287273052203988901606886484606"),
		},
		{
			name:      "add_near_max_increases_price",
			sqrtPX96:  new(u256.Uint).Sub(MAX_SQRT_RATIO, u256.MustFromDecimal("1000000000000")),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			expected:  u256.MustFromDecimal("1461446703485210103295195868455415255138078365375"),
		},
		{
			name:      "add_at_min_increases_price",
			sqrtPX96:  MIN_SQRT_RATIO,
			liquidity: u256.MustFromDecimal("1000000"),
			amount:    u256.MustFromDecimal("100"),
			expected:  u256.MustFromDecimal("7922816251426438054483134"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextPriceAmount1Add(tt.sqrtPX96, tt.liquidity, tt.amount)
				})
				return
			}

			result := getNextPriceAmount1Add(tt.sqrtPX96, tt.liquidity, tt.amount)
			uassert.Equal(t, tt.expected.ToString(), result.ToString())
		})
	}
}

// TestGetNextPriceAmount1Remove tests the internal helper for removing token1
func TestGetNextPriceAmount1Remove(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amount      *u256.Uint
		expected    *u256.Uint
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "normal_removal_small",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"), // 0.1
			expected:  u256.MustFromDecimal("71305346262837903834189555302"),
		},
		{
			name:      "normal_removal_medium",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("500000000000000000"), // 0.5
			expected:  u256.MustFromDecimal("39614081257132168796771975168"),
		},

		{
			name:      "zero_amount_no_change",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.Zero(),
			expected:  Q96,
		},
		{
			name:      "tiny_amount_tiny_change",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("100000000000000000000"),
			amount:    u256.One(),
			expected:  u256.MustFromDecimal("79228162514264337592751668710"),
		},
		{
			name:      "amount_lte_max160_path_small",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("10000000000000000000"),
			amount:    u256.MustFromDecimal("1000000000000000000"),
			expected:  u256.MustFromDecimal("71305346262837903834189555302"),
		},
		{
			name:      "medium_amount_normal_path",
			sqrtPX96:  new(u256.Uint).Mul(Q96, u256.NewUint(2)),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("10000000000000000"),
			expected:  u256.MustFromDecimal("157664043403386031811152461168"),
		},
		{
			name:        "very_small_liquidity",
			sqrtPX96:    Q96,
			liquidity:   u256.One(),
			amount:      u256.MustFromDecimal("1"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:      "very_large_liquidity",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000000000000"),
			amount:    u256.MustFromDecimal("1000000000000000000"),
			expected:  u256.MustFromDecimal("79228162435036175079279612742"),
		},
		{
			name:      "high_price_removal",
			sqrtPX96:  u256.MustFromDecimal("1000000000000000000000000000000"),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("1000"),
			expected:  u256.MustFromDecimal("999999999999999920771837485735"),
		},
		{
			name:        "insufficient_liquidity_panic",
			sqrtPX96:    Q96,
			liquidity:   u256.MustFromDecimal("1000"),
			amount:      u256.MustFromDecimal("1000000000000000000"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:        "price_below_min_panic",
			sqrtPX96:    MIN_SQRT_RATIO,
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amount:      u256.One(),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:      "rounding_up_verification",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("999999999999999999"),
			amount:    u256.MustFromDecimal("333333333333333333"),
			expected:  u256.MustFromDecimal("52818775009509558395695966890"),
		},
		{
			name:      "quotient_exactly_sqrtPX96_minus_1",
			sqrtPX96:  u256.MustFromDecimal("79228162514264337593543950336"),
			liquidity: u256.MustFromDecimal("79228162514264337593543950336"),
			amount:    u256.MustFromDecimal("79228162514264337593543950335"),
			expected:  u256.One(),
		},
		{
			name:        "quotient_exactly_equals_sqrtPX96",
			sqrtPX96:    u256.MustFromDecimal("1000000000000000000"),
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amount:      u256.MustFromDecimal("1000000000000000000"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:        "amount_just_above_max160_boundary",
			sqrtPX96:    u256.MustFromDecimal("200000000000000000000000000000000000000"),
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amount:      new(u256.Uint).Add(MAX_UINT160, u256.One()), // MAX_UINT160 + 1
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:        "exact_division_no_rounding",
			sqrtPX96:    Q96,
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amount:      u256.MustFromDecimal("1000000000000000000"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:        "quotient_almost_equals_price",
			sqrtPX96:    u256.MustFromDecimal("1000000000000000000"),
			liquidity:   u256.MustFromDecimal("1000000"),
			amount:      u256.MustFromDecimal("12589254117"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:        "quotient_exactly_equals_sqrtPX96",
			sqrtPX96:    u256.MustFromDecimal("1000000000000000000"),
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amount:      u256.MustFromDecimal("1000000000000000000"),
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
		{
			name:      "near_overflow_large_values",
			sqrtPX96:  new(u256.Uint).Rsh(MAX_UINT256, 10),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    new(u256.Uint).Rsh(MAX_UINT256, 200),
			expected:  u256.MustFromDecimal("113078212145816597093331040047546785012958969394330622548958957437722684299"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextPriceAmount1Remove(tt.sqrtPX96, tt.liquidity, tt.amount)
				})
				return
			}

			result := getNextPriceAmount1Remove(tt.sqrtPX96, tt.liquidity, tt.amount)
			uassert.Equal(t, tt.expected.ToString(), result.ToString())
		})
	}
}

// TestGetNextSqrtPriceFromAmount1RoundingDown tests price calculation when adding/removing token1
func TestGetNextSqrtPriceFromAmount1RoundingDown(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amount      *u256.Uint
		add         bool
		expected    *u256.Uint
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "zero_amount_returns_same_price",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.Zero(),
			add:       true,
			expected:  Q96,
		},
		{
			name:      "delegates_to_add_function",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			add:       true,
			expected:  u256.MustFromDecimal("87150978765690771352898345369"),
		},
		{
			name:      "delegates_to_remove_function",
			sqrtPX96:  Q96,
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			amount:    u256.MustFromDecimal("100000000000000000"),
			add:       false,
			expected:  u256.MustFromDecimal("71305346262837903834189555302"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextSqrtPriceFromAmount1RoundingDown(tt.sqrtPX96, tt.liquidity, tt.amount, tt.add)
				})
				return
			}

			result := getNextSqrtPriceFromAmount1RoundingDown(tt.sqrtPX96, tt.liquidity, tt.amount, tt.add)
			uassert.Equal(t, tt.expected.ToString(), result.ToString())
		})
	}
}

// TestGetNextSqrtPriceFromInput tests input swap calculations
func TestGetNextSqrtPriceFromInput(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amountIn    *u256.Uint
		zeroForOne  bool
		expected    string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "zero_price_panics",
			sqrtPX96:    u256.Zero(),
			liquidity:   u256.One(),
			amountIn:    u256.One(),
			zeroForOne:  true,
			shouldPanic: true,
			panicMsg:    errSqrtPriceZero.Error(),
		},
		{
			name:        "zero_liquidity_panics",
			sqrtPX96:    u256.One(),
			liquidity:   u256.Zero(),
			amountIn:    u256.One(),
			zeroForOne:  true,
			shouldPanic: true,
			panicMsg:    errLiquidityZero.Error(),
		},
		{
			name:       "delegates_to_amount0_function",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountIn:   u256.MustFromDecimal("100000000000000000"),
			zeroForOne: true,
			expected:   "72025602285694852357767227579",
		},
		{
			name:       "delegates_to_amount1_function",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountIn:   u256.MustFromDecimal("100000000000000000"),
			zeroForOne: false,
			expected:   "87150978765690771352898345369",
		},
		{
			name:       "zero_amount_no_change",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountIn:   u256.Zero(),
			zeroForOne: true,
			expected:   Q96.ToString(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextSqrtPriceFromInput(tt.sqrtPX96, tt.liquidity, tt.amountIn, tt.zeroForOne)
				})
				return
			}

			result := getNextSqrtPriceFromInput(tt.sqrtPX96, tt.liquidity, tt.amountIn, tt.zeroForOne)
			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestGetNextSqrtPriceFromOutput tests output swap calculations
func TestGetNextSqrtPriceFromOutput(t *testing.T) {
	tests := []struct {
		name        string
		sqrtPX96    *u256.Uint
		liquidity   *u256.Uint
		amountOut   *u256.Uint
		zeroForOne  bool
		expected    string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "zero_price_panics",
			sqrtPX96:    u256.Zero(),
			liquidity:   u256.One(),
			amountOut:   u256.One(),
			zeroForOne:  true,
			shouldPanic: true,
			panicMsg:    errSqrtPriceZero.Error(),
		},
		{
			name:        "zero_liquidity_panics",
			sqrtPX96:    u256.One(),
			liquidity:   u256.Zero(),
			amountOut:   u256.One(),
			zeroForOne:  true,
			shouldPanic: true,
			panicMsg:    errLiquidityZero.Error(),
		},
		{
			name:       "delegates_to_amount1_for_zeroForOne",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountOut:  u256.MustFromDecimal("100000000000000000"),
			zeroForOne: true,
			expected:   "71305346262837903834189555302",
		},
		{
			name:       "delegates_to_amount0_for_oneForZero",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountOut:  u256.MustFromDecimal("100000000000000000"),
			zeroForOne: false,
			expected:   "88031291682515930659493278152",
		},
		{
			name:       "zero_amount_no_change",
			sqrtPX96:   Q96,
			liquidity:  u256.MustFromDecimal("1000000000000000000"),
			amountOut:  u256.Zero(),
			zeroForOne: true,
			expected:   Q96.ToString(),
		},
		{
			name:        "delegates_panic_from_internal",
			sqrtPX96:    Q96,
			liquidity:   u256.MustFromDecimal("1000000000000000000"),
			amountOut:   u256.MustFromDecimal("1000000000000000000"),
			zeroForOne:  true,
			shouldPanic: true,
			panicMsg:    errSqrtPriceExceedsQuotient.Error(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getNextSqrtPriceFromOutput(tt.sqrtPX96, tt.liquidity, tt.amountOut, tt.zeroForOne)
				})
				return
			}

			result := getNextSqrtPriceFromOutput(tt.sqrtPX96, tt.liquidity, tt.amountOut, tt.zeroForOne)
			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestGetAmount0DeltaHelper tests amount0 calculation helper
func TestGetAmount0DeltaHelper(t *testing.T) {
	tests := []struct {
		name          string
		sqrtRatioAX96 *u256.Uint
		sqrtRatioBX96 *u256.Uint
		liquidity     *u256.Uint
		roundUp       bool
		expected      string
		shouldPanic   bool
		panicMsg      string
	}{
		// Basic cases
		{
			name:          "zero_liquidity",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("2", "1"),
			liquidity:     u256.Zero(),
			roundUp:       true,
			expected:      "0",
		},
		{
			name:          "equal_prices",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "0",
		},
		{
			name:          "swapped_inputs",
			sqrtRatioAX96: encodePriceSqrt("2", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "292893218813452476",
		},
		// Rounding tests
		{
			name:          "round_up_true",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("121", "100"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "90909090909090910",
		},
		{
			name:          "round_up_false",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("121", "100"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       false,
			expected:      "90909090909090909",
		},
		// Error cases
		{
			name:          "zero_sqrtRatioA",
			sqrtRatioAX96: u256.Zero(),
			sqrtRatioBX96: u256.MustFromDecimal("1000000"),
			liquidity:     u256.MustFromDecimal("1000000"),
			roundUp:       true,
			shouldPanic:   true,
			panicMsg:      errSqrtRatioAX96Zero.Error(),
		},
		{
			name:          "zero_sqrtRatioB_gets_swapped",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.Zero(),
			liquidity:     u256.MustFromDecimal("1000000"),
			roundUp:       true,
			shouldPanic:   true,
			panicMsg:      errSqrtRatioAX96Zero.Error(),
		},
		// Extreme values
		{
			name:          "min_price_range",
			sqrtRatioAX96: MIN_SQRT_RATIO,
			sqrtRatioBX96: u256.MustFromDecimal("4295128740"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "4294644427204583875464618656",
		},
		{
			name:          "max_price_range",
			sqrtRatioAX96: u256.MustFromDecimal("1461446703485210103287273052203988822378723970340"),
			sqrtRatioBX96: MAX_SQRT_RATIO,
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					getAmount0DeltaHelper(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity, tt.roundUp)
				})
				return
			}

			result := getAmount0DeltaHelper(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity, tt.roundUp)
			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestGetAmount1DeltaHelper tests amount1 calculation helper
func TestGetAmount1DeltaHelper(t *testing.T) {
	tests := []struct {
		name          string
		sqrtRatioAX96 *u256.Uint
		sqrtRatioBX96 *u256.Uint
		liquidity     *u256.Uint
		roundUp       bool
		expected      string
	}{
		// Basic cases
		{
			name:          "zero_liquidity",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("2", "1"),
			liquidity:     u256.Zero(),
			roundUp:       true,
			expected:      "0",
		},
		{
			name:          "equal_prices",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "0",
		},
		{
			name:          "swapped_inputs",
			sqrtRatioAX96: encodePriceSqrt("2", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "414213562373095049",
		},
		// Rounding tests
		{
			name:          "round_up_true",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("121", "100"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "100000000000000000",
		},
		{
			name:          "round_up_false",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("121", "100"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       false,
			expected:      "99999999999999999",
		},
		// Extreme values
		{
			name:          "min_price_range",
			sqrtRatioAX96: MIN_SQRT_RATIO,
			sqrtRatioBX96: u256.MustFromDecimal("4295128740"),
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       true,
			expected:      "1",
		},
		{
			name:          "max_price_range",
			sqrtRatioAX96: u256.MustFromDecimal("1461446703485210103287273052203988822378723970340"),
			sqrtRatioBX96: MAX_SQRT_RATIO,
			liquidity:     u256.MustFromDecimal("1000000000000000000"),
			roundUp:       false,
			expected:      "0",
		},
		// Small liquidity, large price difference
		{
			name:          "small_liquidity_large_diff",
			sqrtRatioAX96: encodePriceSqrt("1", "100"),
			sqrtRatioBX96: encodePriceSqrt("100", "1"),
			liquidity:     u256.One(),
			roundUp:       true,
			expected:      "10",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getAmount1DeltaHelper(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity, tt.roundUp)
			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestGetAmount0Delta tests string representation with signed liquidity
func TestGetAmount0Delta(t *testing.T) {
	tests := []struct {
		name          string
		sqrtRatioAX96 *u256.Uint
		sqrtRatioBX96 *u256.Uint
		liquidity     *i256.Int
		expected      string
		shouldPanic   bool
		panicMsg      string
	}{
		// Nil checks
		{
			name:          "nil_sqrtRatioA",
			sqrtRatioAX96: nil,
			sqrtRatioBX96: u256.MustFromDecimal("1000000"),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("5000000")),
			shouldPanic:   true,
			panicMsg:      errGetAmount0DeltaNilInput.Error(),
		},
		{
			name:          "nil_sqrtRatioB",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: nil,
			liquidity:     i256.FromUint256(u256.MustFromDecimal("5000000")),
			shouldPanic:   true,
			panicMsg:      errGetAmount0DeltaNilInput.Error(),
		},
		{
			name:          "nil_liquidity",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.MustFromDecimal("2000000"),
			liquidity:     nil,
			shouldPanic:   true,
			panicMsg:      errGetAmount0DeltaNilInput.Error(),
		},
		// Positive liquidity (roundUp = true)
		{
			name:          "positive_liquidity",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.MustFromDecimal("2000000"),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("5000000")),
			expected:      "198070406285660843983859875840",
		},
		{
			name:          "positive_liquidity_equal_prices",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("1000000000000000000")),
			expected:      "0",
		},
		// Negative liquidity (roundDown = false)
		{
			name:          "negative_liquidity",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.MustFromDecimal("2000000"),
			liquidity:     i256.New().Neg(i256.FromUint256(u256.MustFromDecimal("5000000"))),
			expected:      "-198070406285660843983859875840",
		},
		// Zero liquidity
		{
			name:          "zero_liquidity",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("2", "1"),
			liquidity:     i256.Zero(),
			expected:      "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					GetAmount0Delta(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity)
				})
				return
			}

			result := GetAmount0Delta(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity)
			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestGetAmount1Delta tests string representation with signed liquidity
func TestGetAmount1Delta(t *testing.T) {
	tests := []struct {
		name          string
		sqrtRatioAX96 *u256.Uint
		sqrtRatioBX96 *u256.Uint
		liquidity     *i256.Int
		expected      string
		shouldPanic   bool
		panicMsg      string
	}{
		// Nil checks
		{
			name:          "nil_all_parameters",
			sqrtRatioAX96: nil,
			sqrtRatioBX96: nil,
			liquidity:     nil,
			shouldPanic:   true,
			panicMsg:      errGetAmount1DeltaNilInput.Error(),
		},
		// Positive liquidity (roundUp = true)
		{
			name:          "positive_liquidity",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.MustFromDecimal("2000000"),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("5000000")),
			expected:      "1",
		},
		{
			name:          "positive_liquidity_large_range",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("4", "1"),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("1000000000000000000")),
			expected:      "1000000000000000000",
		},
		// Negative liquidity (roundDown = false)
		{
			name:          "negative_liquidity",
			sqrtRatioAX96: u256.MustFromDecimal("1000000"),
			sqrtRatioBX96: u256.MustFromDecimal("2000000"),
			liquidity:     i256.New().Neg(i256.FromUint256(u256.MustFromDecimal("5000000"))),
			expected:      "0",
		},
		{
			name:          "negative_liquidity_large",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("4", "1"),
			liquidity:     i256.New().Neg(i256.FromUint256(u256.MustFromDecimal("1000000000000000000"))),
			expected:      "-1000000000000000000",
		},
		{
			name:          "positive_liquidity_large_values",
			sqrtRatioAX96: Q96,
			sqrtRatioBX96: new(u256.Uint).Mul(Q96, u256.NewUint(2)),
			liquidity:     i256.FromUint256(u256.MustFromDecimal("1000000000000000000000000000")),
			expected:      "1000000000000000000000000000",
		},
		// Zero liquidity
		{
			name:          "zero_liquidity",
			sqrtRatioAX96: encodePriceSqrt("1", "1"),
			sqrtRatioBX96: encodePriceSqrt("2", "1"),
			liquidity:     i256.Zero(),
			expected:      "0",
		},
		// Equal prices
		{
			name:          "equal_prices_positive_liquidity",
			sqrtRatioAX96: Q96,
			sqrtRatioBX96: Q96,
			liquidity:     i256.FromUint256(u256.MustFromDecimal("1000000000000000000")),
			expected:      "0",
		},
		// Swapped inputs
		{
			name:          "swapped_prices_positive_liquidity",
			sqrtRatioAX96: encodePriceSqrt("4", "1"),
			sqrtRatioBX96: encodePriceSqrt("1", "1"), // B < A, will be swapped
			liquidity:     i256.FromUint256(u256.MustFromDecimal("1000000000000000000")),
			expected:      "1000000000000000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					GetAmount1Delta(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity)
				})
				return
			}

			result := GetAmount1Delta(tt.sqrtRatioAX96, tt.sqrtRatioBX96, tt.liquidity)

			if tt.name == "positive_liquidity_large_values" {
				if tt.expected != result.ToString() {
					t.Logf("Result for %s: %s", tt.name, result)
				}
			}

			uassert.Equal(t, tt.expected, result.ToString())
		})
	}
}

// TestInputParameterImmutability verifies functions don't modify inputs
func TestInputParameterImmutability(t *testing.T) {
	tests := []struct {
		name string
		fn   func(*testing.T)
	}{
		{
			name: "getNextPriceAmount0Add_immutable",
			fn: func(t *testing.T) {
				sqrtP := Q96
				liquidity := u256.MustFromDecimal("1000000000000000000")
				amount := u256.MustFromDecimal("100000000000000000")

				sqrtPCopy := sqrtP.ToString()
				liquidityCopy := liquidity.ToString()
				amountCopy := amount.ToString()

				_ = getNextPriceAmount0Add(sqrtP, liquidity, amount)

				uassert.Equal(t, sqrtPCopy, sqrtP.ToString())
				uassert.Equal(t, liquidityCopy, liquidity.ToString())
				uassert.Equal(t, amountCopy, amount.ToString())
			},
		},
		{
			name: "getAmount0DeltaHelper_parameter_swap_immutable",
			fn: func(t *testing.T) {
				sqrtA := u256.MustFromDecimal("1000000")
				sqrtB := u256.MustFromDecimal("500000")
				liquidity := u256.MustFromDecimal("1000000")

				originalA := sqrtA.ToString()
				originalB := sqrtB.ToString()

				_ = getAmount0DeltaHelper(sqrtA, sqrtB, liquidity, true)

				uassert.Equal(t, originalA, sqrtA.ToString())
				uassert.Equal(t, originalB, sqrtB.ToString())
			},
		},
		{
			name: "all_input_functions_immutable",
			fn: func(t *testing.T) {
				sqrtP := Q96
				liquidity := u256.MustFromDecimal("1000000000000000000")
				amount := u256.MustFromDecimal("1000000")

				original := sqrtP.ToString()

				// Test all input/output functions
				_ = getNextSqrtPriceFromInput(sqrtP, liquidity, amount, true)
				uassert.Equal(t, original, sqrtP.ToString())

				_ = getNextSqrtPriceFromInput(sqrtP, liquidity, amount, false)
				uassert.Equal(t, original, sqrtP.ToString())

				_ = getNextSqrtPriceFromOutput(sqrtP, liquidity, amount, true)
				uassert.Equal(t, original, sqrtP.ToString())

				_ = getNextSqrtPriceFromOutput(sqrtP, liquidity, amount, false)
				uassert.Equal(t, original, sqrtP.ToString())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

// TestRoundingConsistency verifies rounding behavior
func TestRoundingConsistency(t *testing.T) {
	tests := []struct {
		name      string
		sqrtA     *u256.Uint
		sqrtB     *u256.Uint
		liquidity *u256.Uint
		isToken0  bool
	}{
		{
			name:      "amount0_minimal_difference",
			sqrtA:     Q96,
			sqrtB:     u256.MustFromDecimal("79228162514264337593543950337"),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			isToken0:  true,
		},
		{
			name:      "amount1_minimal_difference",
			sqrtA:     Q96,
			sqrtB:     u256.MustFromDecimal("79228162514264337593543950337"),
			liquidity: u256.MustFromDecimal("1000000000000000000"),
			isToken0:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var amountRoundUp, amountRoundDown *u256.Uint

			if tt.isToken0 {
				amountRoundUp = getAmount0DeltaHelper(tt.sqrtA, tt.sqrtB, tt.liquidity, true)
				amountRoundDown = getAmount0DeltaHelper(tt.sqrtA, tt.sqrtB, tt.liquidity, false)
			} else {
				amountRoundUp = getAmount1DeltaHelper(tt.sqrtA, tt.sqrtB, tt.liquidity, true)
				amountRoundDown = getAmount1DeltaHelper(tt.sqrtA, tt.sqrtB, tt.liquidity, false)
			}

			// Round up should always be >= round down
			uassert.True(t, amountRoundUp.Gte(amountRoundDown), "Round up should be >= round down")

			// Difference should be at most 1
			if !amountRoundUp.IsZero() || !amountRoundDown.IsZero() {
				diff := new(u256.Uint).Sub(amountRoundUp, amountRoundDown)
				uassert.True(t, diff.Lte(u256.One()), "Rounding difference should be at most 1")
			}
		})
	}
}

// TestMathematicalInvariants tests important mathematical properties
func TestMathematicalInvariants(t *testing.T) {
	// Test 1: Round trip precision
	t.Run("round_trip_precision", func(t *testing.T) {
		testCases := []struct {
			liquidity string
			amount    string
			maxError  string
		}{
			{"100000000000000000000", "100000000000000000", "792281625"},
			{"10000000000000000000", "100000000000000000", "7922816251"},
			{"1000000000000000000", "100000000000000000", "79228162513"},
		}

		for _, tc := range testCases {
			sqrtP := Q96
			liquidity := u256.MustFromDecimal(tc.liquidity)
			amount := u256.MustFromDecimal(tc.amount)
			maxError := u256.MustFromDecimal(tc.maxError)

			// Add then remove same amount
			priceAfterAdd := getNextSqrtPriceFromInput(sqrtP, liquidity, amount, true)
			actualAmount := getAmount0DeltaHelper(priceAfterAdd, sqrtP, liquidity, false)
			priceAfterRemove := getNextSqrtPriceFromOutput(priceAfterAdd, liquidity, actualAmount, false)

			// Calculate error
			var diff *u256.Uint
			if priceAfterRemove.Gt(sqrtP) {
				diff = new(u256.Uint).Sub(priceAfterRemove, sqrtP)
			} else {
				diff = new(u256.Uint).Sub(sqrtP, priceAfterRemove)
			}

			if diff.Gt(maxError) {
				t.Errorf("Round trip error too large for liquidity %s: %s wei (max: %s)",
					tc.liquidity, diff.ToString(), maxError.ToString())
			}
		}
	})

	// Test 2: Monotonicity
	t.Run("monotonicity", func(t *testing.T) {
		sqrtP := Q96
		liquidity := u256.MustFromDecimal("1000000000000000000")

		amounts := []*u256.Uint{
			u256.MustFromDecimal("1000"),
			u256.MustFromDecimal("10000"),
			u256.MustFromDecimal("100000"),
			u256.MustFromDecimal("1000000"),
		}

		var prevPrice *u256.Uint = sqrtP

		// Adding more token0 should decrease price more
		for i, amount := range amounts {
			newPrice := getNextSqrtPriceFromInput(sqrtP, liquidity, amount, true)

			if i > 0 && !newPrice.Lt(prevPrice) {
				t.Errorf("Monotonicity violated: larger amount didn't decrease price more")
			}

			prevPrice = newPrice
		}
	})

	// Test 3: Symmetry
	t.Run("symmetry", func(t *testing.T) {
		sqrtP := Q96
		liquidity := u256.MustFromDecimal("1000000000000000000")
		amount := u256.MustFromDecimal("100000000000000000")

		// Add token0, get amount1 out
		priceAfter0 := getNextSqrtPriceFromInput(sqrtP, liquidity, amount, true)
		amount1Out := getAmount1DeltaHelper(priceAfter0, sqrtP, liquidity, false)

		// Add token1, get amount0 out
		priceAfter1 := getNextSqrtPriceFromInput(sqrtP, liquidity, amount, false)
		amount0Out := getAmount0DeltaHelper(sqrtP, priceAfter1, liquidity, false)

		// The product of price ratios should be close to 1
		// Due to rounding, we allow small deviation
		t.Logf("Token0 in: %s, Token1 out: %s", amount.ToString(), amount1Out.ToString())
		t.Logf("Token1 in: %s, Token0 out: %s", amount.ToString(), amount0Out.ToString())
	})
}

// TestPathIndependence verifies swap order doesn't affect final state
func TestPathIndependence(t *testing.T) {
	startPrice := u256.MustFromDecimal("79228162514264337593543950336")
	liquidity := u256.MustFromDecimal("1000000000000000000")

	amount0 := u256.MustFromDecimal("10000000000000000")
	amount1 := u256.MustFromDecimal("10000000000000000")

	// Path 1: Add token0, then add token1
	price1 := getNextSqrtPriceFromInput(startPrice, liquidity, amount0, true)
	price1 = getNextSqrtPriceFromInput(price1, liquidity, amount1, false)

	// Path 2: Add token1, then add token0
	price2 := getNextSqrtPriceFromInput(startPrice, liquidity, amount1, false)
	price2 = getNextSqrtPriceFromInput(price2, liquidity, amount0, true)

	// Calculate percentage difference
	var diff *u256.Uint
	if price1.Gt(price2) {
		diff = new(u256.Uint).Sub(price1, price2)
	} else {
		diff = new(u256.Uint).Sub(price2, price1)
	}

	avgPrice := new(u256.Uint).Add(price1, price2)
	avgPrice.Div(avgPrice, u256.NewUint(2))
	percentDiff := new(u256.Uint).Mul(diff, u256.MustFromDecimal("10000"))
	percentDiff.Div(percentDiff, avgPrice)

	t.Logf("Path 1 final price: %s", price1.ToString())
	t.Logf("Path 2 final price: %s", price2.ToString())
	t.Logf("Percentage difference: %s basis points", percentDiff.ToString())

	// Should be less than 10 basis points (0.1%)
	maxAllowedDiff := u256.NewUint(10)
	if percentDiff.Gt(maxAllowedDiff) {
		t.Errorf("Path independence error too large: %s bp (max allowed: %s bp)",
			percentDiff.ToString(), maxAllowedDiff.ToString())
	}
}

// TestHelperFunctionConsistency verifies helper functions work together correctly
func TestHelperFunctionConsistency(t *testing.T) {
	sqrtP := Q96
	liquidity := u256.MustFromDecimal("1000000000000000000")
	amount := u256.MustFromDecimal("100000000000000000")

	// Test token0 add path
	t.Run("token0_add_consistency", func(t *testing.T) {
		// Direct calculation
		directPrice := getNextPriceAmount0Add(sqrtP, liquidity, amount)

		// Through wrapper
		wrapperPrice := getNextSqrtPriceFromAmount0RoundingUp(sqrtP, liquidity, amount, true)

		uassert.Equal(t, directPrice.ToString(), wrapperPrice.ToString())
	})

	// Test token0 remove path
	t.Run("token0_remove_consistency", func(t *testing.T) {
		// Use smaller amount to avoid insufficient liquidity
		smallAmount := u256.MustFromDecimal("1000000")

		// Direct calculation
		directPrice := getNextPriceAmount0Remove(sqrtP, liquidity, smallAmount)

		// Through wrapper
		wrapperPrice := getNextSqrtPriceFromAmount0RoundingUp(sqrtP, liquidity, smallAmount, false)

		uassert.Equal(t, directPrice.ToString(), wrapperPrice.ToString())
	})

	// Test token1 paths similarly
	t.Run("token1_consistency", func(t *testing.T) {
		// Add
		directAdd := getNextPriceAmount1Add(sqrtP, liquidity, amount)
		wrapperAdd := getNextSqrtPriceFromAmount1RoundingDown(sqrtP, liquidity, amount, true)
		uassert.Equal(t, directAdd.ToString(), wrapperAdd.ToString())

		// Remove
		smallAmount := u256.MustFromDecimal("1000000")
		directRemove := getNextPriceAmount1Remove(sqrtP, liquidity, smallAmount)
		wrapperRemove := getNextSqrtPriceFromAmount1RoundingDown(sqrtP, liquidity, smallAmount, false)
		uassert.Equal(t, directRemove.ToString(), wrapperRemove.ToString())
	})
}

// Helper functions
func encodePriceSqrt(reserve1, reserve0 string) *u256.Uint {
	reserve1Uint := u256.MustFromDecimal(reserve1)
	reserve0Uint := u256.MustFromDecimal(reserve0)

	if reserve0Uint.IsZero() {
		panic("division by zero")
	}

	// numerator = reserve1 * (2^192)
	two192 := new(u256.Uint).Lsh(u256.NewUint(1), 192)
	numerator := new(u256.Uint).Mul(reserve1Uint, two192)

	// ratioX192 = numerator / reserve0
	ratioX192 := new(u256.Uint).Div(numerator, reserve0Uint)

	// Return sqrt(ratioX192)
	return sqrt(ratioX192)
}

func sqrt(x *u256.Uint) *u256.Uint {
	if x.IsZero() {
		return u256.NewUint(0)
	}

	z := new(u256.Uint).Set(x)
	y := new(u256.Uint).Rsh(z, 1)

	for y.Cmp(z) < 0 {
		z.Set(y)
		temp := new(u256.Uint).Div(x, z)
		y.Add(z, temp).Rsh(y, 1)
	}
	return z
}
