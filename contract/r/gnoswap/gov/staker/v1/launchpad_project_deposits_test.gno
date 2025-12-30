package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/staker"
)

func TestLaunchpadProjectDeposits_getLaunchpadProjectDeposit(t *testing.T) {
	tests := []struct {
		name          string
		setup         func() *LaunchpadProjectDepositsResolver
		ownerAddress  string
		expectedValue int64
		expectedExists bool
	}{
		{
			name: "returns zero and false when no deposit exists",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			expectedValue:  0,
			expectedExists: false,
		},
		{
			name: "returns deposit value when exists",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			expectedValue:  1000000,
			expectedExists: true,
		},
		{
			name: "returns correct deposit for multiple owners",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				resolver.SetDeposit(testutils.TestAddress("owner2").String(), 2000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner2").String(),
			expectedValue:  2000000,
			expectedExists: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			value, exists := resolver.getLaunchpadProjectDeposit(tc.ownerAddress)

			// then
			uassert.Equal(t, value, tc.expectedValue)
			uassert.Equal(t, exists, tc.expectedExists)
		})
	}
}

func TestLaunchpadProjectDeposits_setLaunchpadProjectDeposit(t *testing.T) {
	tests := []struct {
		name          string
		setup         func() *LaunchpadProjectDepositsResolver
		ownerAddress  string
		depositAmount int64
		expectedValue int64
	}{
		{
			name: "sets deposit for new owner",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 1000000,
			expectedValue: 1000000,
		},
		{
			name: "overwrites existing deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 2000000,
			expectedValue: 2000000,
		},
		{
			name: "sets deposit to zero",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 0,
			expectedValue: 0,
		},
		{
			name: "sets large deposit value",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 9223372036854775807, // max int64
			expectedValue: 9223372036854775807,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			result := resolver.setLaunchpadProjectDeposit(tc.ownerAddress, tc.depositAmount)

			// then
			uassert.True(t, result)
			value, exists := resolver.GetDeposit(tc.ownerAddress)
			uassert.True(t, exists)
			uassert.Equal(t, value, tc.expectedValue)
		})
	}
}

func TestLaunchpadProjectDeposits_addDeposit(t *testing.T) {
	tests := []struct {
		name          string
		setup         func() *LaunchpadProjectDepositsResolver
		ownerAddress  string
		addAmount     int64
		expectedValue int64
	}{
		{
			name: "adds to non-existent deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			addAmount:     1000000,
			expectedValue: 1000000,
		},
		{
			name: "adds to existing deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 500000)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			addAmount:     500000,
			expectedValue: 1000000,
		},
		{
			name: "adds zero amount",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			addAmount:     0,
			expectedValue: 1000000,
		},
		{
			name: "prevents negative deposit when adding negative amount",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 500000)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			addAmount:     -1000000,
			expectedValue: 0, // Should not go negative
		},
		{
			name: "boundary test - add positive amount to max value causes overflow",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 9223372036854775806)
				return resolver
			},
			ownerAddress:  testutils.TestAddress("owner1").String(),
			addAmount:     1,
			expectedValue: 9223372036854775807, // Should result in max int64
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			resolver.addDeposit(tc.ownerAddress, tc.addAmount)

			// then
			value, _ := resolver.GetDeposit(tc.ownerAddress)
			uassert.Equal(t, value, tc.expectedValue)
		})
	}
}

func TestLaunchpadProjectDeposits_removeDeposit(t *testing.T) {
	tests := []struct {
		name           string
		setup          func() *LaunchpadProjectDepositsResolver
		ownerAddress   string
		removeAmount   int64
		expectedValue  int64
		expectedExists bool
	}{
		{
			name: "removes from existing deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			removeAmount:   500000,
			expectedValue:  500000,
			expectedExists: true,
		},
		{
			name: "prevents negative deposit when removing more than balance",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 500000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			removeAmount:   1000000,
			expectedValue:  0,
			expectedExists: true,
		},
		{
			name: "does nothing when owner does not exist",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			removeAmount:   1000000,
			expectedValue:  0,
			expectedExists: false,
		},
		{
			name: "removes zero amount",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			removeAmount:   0,
			expectedValue:  1000000,
			expectedExists: true,
		},
		{
			name: "removes entire deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			removeAmount:   1000000,
			expectedValue:  0,
			expectedExists: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			resolver.removeDeposit(tc.ownerAddress, tc.removeAmount)

			// then
			value, exists := resolver.GetDeposit(tc.ownerAddress)
			uassert.Equal(t, value, tc.expectedValue)
			uassert.Equal(t, exists, tc.expectedExists)
		})
	}
}

func TestLaunchpadProjectDeposits_GetDeposit(t *testing.T) {
	tests := []struct {
		name           string
		setup          func() *LaunchpadProjectDepositsResolver
		ownerAddress   string
		expectedValue  int64
		expectedExists bool
	}{
		{
			name: "returns zero and false when no deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			expectedValue:  0,
			expectedExists: false,
		},
		{
			name: "returns deposit value when exists",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress:   testutils.TestAddress("owner1").String(),
			expectedValue:  1000000,
			expectedExists: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			value, exists := resolver.GetDeposit(tc.ownerAddress)

			// then
			uassert.Equal(t, value, tc.expectedValue)
			uassert.Equal(t, exists, tc.expectedExists)
		})
	}
}

func TestLaunchpadProjectDeposits_SetDeposit(t *testing.T) {
	tests := []struct {
		name          string
		ownerAddress  string
		depositAmount int64
		expectedValue int64
	}{
		{
			name:          "sets deposit",
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 1000000,
			expectedValue: 1000000,
		},
		{
			name:          "sets zero deposit",
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 0,
			expectedValue: 0,
		},
		{
			name:          "sets max int64 deposit",
			ownerAddress:  testutils.TestAddress("owner1").String(),
			depositAmount: 9223372036854775807,
			expectedValue: 9223372036854775807,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			deposits := staker.NewLaunchpadProjectDeposits()
			resolver := NewLaunchpadProjectDepositsResolver(deposits)

			// when
			resolver.SetDeposit(tc.ownerAddress, tc.depositAmount)

			// then
			value, exists := resolver.GetDeposit(tc.ownerAddress)
			uassert.True(t, exists)
			uassert.Equal(t, value, tc.expectedValue)
		})
	}
}

func TestLaunchpadProjectDeposits_RemoveDeposit(t *testing.T) {
	tests := []struct {
		name          string
		setup         func() *LaunchpadProjectDepositsResolver
		ownerAddress  string
		expectedOk    bool
		shouldExist   bool
	}{
		{
			name: "removes existing deposit",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				return resolver
			},
			ownerAddress: testutils.TestAddress("owner1").String(),
			expectedOk:   true,
			shouldExist:  false,
		},
		{
			name: "returns false when deposit does not exist",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				return NewLaunchpadProjectDepositsResolver(deposits)
			},
			ownerAddress: testutils.TestAddress("owner1").String(),
			expectedOk:   false,
			shouldExist:  false,
		},
		{
			name: "does not affect other deposits",
			setup: func() *LaunchpadProjectDepositsResolver {
				deposits := staker.NewLaunchpadProjectDeposits()
				resolver := NewLaunchpadProjectDepositsResolver(deposits)
				resolver.SetDeposit(testutils.TestAddress("owner1").String(), 1000000)
				resolver.SetDeposit(testutils.TestAddress("owner2").String(), 2000000)
				return resolver
			},
			ownerAddress: testutils.TestAddress("owner1").String(),
			expectedOk:   true,
			shouldExist:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := tc.setup()

			// when
			ok := resolver.RemoveDeposit(tc.ownerAddress)

			// then
			uassert.Equal(t, ok, tc.expectedOk)
			_, exists := resolver.GetDeposit(tc.ownerAddress)
			uassert.Equal(t, exists, tc.shouldExist)
		})
	}
}
