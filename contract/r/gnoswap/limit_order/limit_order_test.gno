package limit_order

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

func TestOrderStatus(t *testing.T) {
	tests := []struct {
		status   OrderStatus
		expected string
	}{
		{OrderStatusActive, "ACTIVE"},
		{OrderStatusExecuted, "EXECUTED"},
		{OrderStatusCancelled, "CANCELLED"},
		{OrderStatusExpired, "EXPIRED"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			// when: convert status to string
			result := tt.status.String()

			// then: verify string matches expected
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetLimitPrice(t *testing.T) {
	tests := []struct {
		name         string
		makingAmount uint64
		takingAmount uint64
		description  string
	}{
		{
			name:         "simple 1:1 ratio",
			makingAmount: 1000000,
			takingAmount: 1000000,
			description:  "Price should be equal to Q96",
		},
		{
			name:         "1:2 ratio",
			makingAmount: 1000000,
			takingAmount: 2000000,
			description:  "Price should be 2 * Q96",
		},
		{
			name:         "2:1 ratio",
			makingAmount: 2000000,
			takingAmount: 1000000,
			description:  "Price should be 0.5 * Q96",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given: create order with specific making/taking amounts
			order := NewLimitOrder(
				1,
				"g1test",
				"pool:path",
				"token0",
				"token1",
				u256.NewUint(tt.makingAmount),
				u256.NewUint(tt.takingAmount),
				0,
				50,
				time.Now().Unix()+3600,
			)

			// when: get limit price
			limitPrice := order.GetLimitPrice()

			// then: price should not be zero
			uassert.False(t, limitPrice.IsZero(), "Limit price should not be zero")

			// then: verify price calculation (scaled by Q96)
			q96 := u256.MustFromDecimal("79228162514264337593543950336")
			expectedPrice := u256.Zero().Mul(u256.NewUint(tt.takingAmount), q96)
			expectedPrice = u256.Zero().Div(expectedPrice, u256.NewUint(tt.makingAmount))

			uassert.True(t, limitPrice.Eq(expectedPrice), "Price calculation mismatch")
		})
	}
}

func TestGetMinimumOutput(t *testing.T) {
	takingAmount := u256.NewUint(1000000)
	feeBps := uint64(50) // 0.5% keeper fee

	tests := []struct {
		name        string
		slippageBps uint64
		expected    string
	}{
		{
			name:        "zero slippage - includes keeper fee",
			slippageBps: 0,
			expected:    "1005025", // 1000000 * 10000 / (10000 - 50) = 1005025.125...
		},
		{
			name:        "with 1% slippage",
			slippageBps: 100,
			expected:    "994974", // 990000 * 10000 / 9950
		},
		{
			name:        "with 5% slippage",
			slippageBps: 500,
			expected:    "954773", // 950000 * 10000 / 9950
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given: create order with slippage and keeper fee
			order := NewLimitOrder(
				1,
				"g1test",
				"pool:path",
				"token0",
				"token1",
				u256.NewUint(1000000),
				takingAmount,
				tt.slippageBps,
				feeBps,
				time.Now().Unix()+3600,
			)

			// when: get minimum output
			minOutput := order.GetMinimumOutput()
			expected := u256.MustFromDecimal(tt.expected)

			// then: verify minimum output includes keeper fee
			uassert.True(t, minOutput.Eq(expected), "Minimum output mismatch")
		})
	}
}

func TestCanExecute(t *testing.T) {
	q96 := u256.MustFromDecimal("79228162514264337593543950336")

	tests := []struct {
		name         string
		makingAmount uint64
		takingAmount uint64
		currentPrice *u256.Uint
		expected     bool
	}{
		{
			name:         "price equals limit - can execute",
			makingAmount: 1000000,
			takingAmount: 1000000,
			currentPrice: q96, // exactly 1:1
			expected:     true,
		},
		{
			name:         "price above limit - can execute",
			makingAmount: 1000000,
			takingAmount: 1000000,
			currentPrice: u256.Zero().Mul(q96, u256.NewUint(2)), // 2:1 (better than required)
			expected:     true,
		},
		{
			name:         "price below limit - cannot execute",
			makingAmount: 1000000,
			takingAmount: 1000000,
			currentPrice: u256.Zero().Div(q96, u256.NewUint(2)), // 0.5:1 (worse than required)
			expected:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given: create order
			order := NewLimitOrder(
				1,
				"g1test",
				"pool:path",
				"token0",
				"token1",
				u256.NewUint(tt.makingAmount),
				u256.NewUint(tt.takingAmount),
				0,
				50,
				time.Now().Unix()+3600,
			)
			// Set deposited to true (required for IsActive check)
			order.SetDeposited(true)

			// when: check if can execute
			result := order.CanExecute(tt.currentPrice)

			// then: verify result
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestIsExpired(t *testing.T) {
	tests := []struct {
		name     string
		expireAt int64
		expected bool
	}{
		{
			name:     "not expired - future expiration",
			expireAt: time.Now().Unix() + 3600,
			expected: false,
		},
		{
			name:     "expired - past expiration",
			expireAt: time.Now().Unix() - 3600,
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given: create order with specific expiration
			order := NewLimitOrder(
				1,
				"g1test",
				"pool:path",
				"token0",
				"token1",
				u256.NewUint(1000000),
				u256.NewUint(1000000),
				0,
				50,
				tt.expireAt,
			)

			// when: check if expired
			result := order.IsExpired()

			// then: verify result
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestLimitOrderSetters(t *testing.T) {
	// given: create a new order
	order := NewLimitOrder(
		1,
		"g1test",
		"pool:path",
		"token0",
		"token1",
		u256.NewUint(1000000),
		u256.NewUint(1000000),
		0,
		50,
		time.Now().Unix()+3600,
	)

	// then: verify initial state
	uassert.Equal(t, OrderStatusActive.String(), order.Status().String())
	uassert.Equal(t, false, order.Deposited())

	// when: set status to executed
	order.SetStatus(OrderStatusExecuted)

	// then: verify status changed
	uassert.Equal(t, OrderStatusExecuted.String(), order.Status().String())

	// when: set deposited to true
	order.SetDeposited(true)

	// then: verify deposited changed
	uassert.Equal(t, true, order.Deposited())
}

func TestLimitOrderGetters(t *testing.T) {
	// given: create order with specific values
	makingAmount := u256.NewUint(1000000)
	takingAmount := u256.NewUint(900000)
	slippageBps := uint64(100)
	feeBps := uint64(50)
	expiredAt := time.Now().Unix() + 3600

	order := NewLimitOrder(
		42,
		"g1owner",
		"gno.land/r/token0:gno.land/r/token1:500",
		"gno.land/r/token0",
		"gno.land/r/token1",
		makingAmount,
		takingAmount,
		slippageBps,
		feeBps,
		expiredAt,
	)

	// then: verify all getters return correct values
	uassert.Equal(t, order.ID(), uint64(42))
	uassert.Equal(t, order.Owner(), address("g1owner"))
	uassert.Equal(t, order.PoolPath(), "gno.land/r/token0:gno.land/r/token1:500")
	uassert.Equal(t, order.InputMint(), address("gno.land/r/token0"))
	uassert.Equal(t, order.OutputMint(), address("gno.land/r/token1"))
	uassert.True(t, order.MakingAmount().Eq(makingAmount), "MakingAmount mismatch")
	uassert.True(t, order.TakingAmount().Eq(takingAmount), "TakingAmount mismatch")
	uassert.Equal(t, order.SlippageBps(), slippageBps)
	uassert.Equal(t, order.FeeBps(), feeBps)
	uassert.Equal(t, order.ExpiredAt(), expiredAt)
}
