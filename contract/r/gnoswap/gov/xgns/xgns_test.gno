package xgns

import (
	"math"
	"testing"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ownable"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/rbac"
)

var (
	adminAddr        = getContractAddress(prbac.ROLE_ADMIN.String())
	govStakerAddress = getContractAddress(prbac.ROLE_GOV_STAKER.String())
	launchpadAddress = getContractAddress(prbac.ROLE_LAUNCHPAD.String())
)

func TestXgns_TotalSupply(t *testing.T) {
	tests := []struct {
		name           string
		mintAmount     int64
		expectedSupply int64
	}{
		{
			name:           "Initial total supply is zero",
			mintAmount:     0,
			expectedSupply: 0,
		},
		{
			name:           "Total supply after minting",
			mintAmount:     1000,
			expectedSupply: 1000,
		},
		{
			name:           "Total supply with minimum amount",
			mintAmount:     1,
			expectedSupply: 1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.mintAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, govStakerAddress, tc.mintAmount)
			}

			// when
			actualSupply := TotalSupply()

			// then
			uassert.Equal(t, tc.expectedSupply, actualSupply)
		})
	}
}

func TestXgns_Mint(t *testing.T) {
	tests := []struct {
		name            string
		caller          address
		to              address
		setupAmount     int64
		amount          int64
		expectedPanic   bool
		expectedMessage string
	}{
		{
			name:   "Success mint to gov staker",
			caller: govStakerAddress,
			to:     govStakerAddress,
			amount: 1000,
		},
		{
			name:   "Success mint with zero amount",
			caller: govStakerAddress,
			to:     govStakerAddress,
			amount: 0,
		},
		{
			name:   "Success mint with minimum amount",
			caller: govStakerAddress,
			to:     govStakerAddress,
			amount: 1,
		},
		{
			name:            "Fail mint with negative amount",
			caller:          govStakerAddress,
			to:              govStakerAddress,
			amount:          -100,
			expectedPanic:   true,
			expectedMessage: "invalid amount",
		},
		{
			name:            "Fail mint causing total supply overflow",
			caller:          govStakerAddress,
			to:              govStakerAddress,
			setupAmount:     math.MaxInt64 - 100,
			amount:          200,
			expectedPanic:   true,
			expectedMessage: "mint overflow",
		},
		{
			name:            "Fail mint by unauthorized caller",
			caller:          adminAddr,
			to:              govStakerAddress,
			amount:          100,
			expectedPanic:   true,
			expectedMessage: "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not gov_staker",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.setupAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, govStakerAddress, tc.setupAmount)
			}

			initialSupply := TotalSupply()
			initialBalance := BalanceOf(tc.to)

			// when & then
			if tc.expectedPanic {
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(tc.caller))
					Mint(cross, tc.to, tc.amount)
				})
			} else {
				testing.SetRealm(testing.NewUserRealm(tc.caller))
				Mint(cross, tc.to, tc.amount)

				expectedSupply := initialSupply + tc.amount
				actualSupply := TotalSupply()
				uassert.Equal(t, expectedSupply, actualSupply)

				expectedBalance := initialBalance + tc.amount
				actualBalance := BalanceOf(tc.to)
				uassert.Equal(t, expectedBalance, actualBalance)
			}
		})
	}
}

func TestXgns_Burn(t *testing.T) {
	tests := []struct {
		name            string
		caller          address
		from            address
		mintAmount      int64
		burnAmount      int64
		expectedPanic   bool
		expectedMessage string
	}{
		{
			name:       "Success burn by gov staker",
			caller:     govStakerAddress,
			from:       govStakerAddress,
			mintAmount: 1000,
			burnAmount: 200,
		},
		{
			name:       "Success burn with zero amount",
			caller:     govStakerAddress,
			from:       govStakerAddress,
			mintAmount: 1000,
			burnAmount: 0,
		},
		{
			name:       "Success burn with minimum amount",
			caller:     govStakerAddress,
			from:       govStakerAddress,
			mintAmount: 10,
			burnAmount: 1,
		},
		{
			name:            "Fail burn with negative amount",
			caller:          govStakerAddress,
			from:            govStakerAddress,
			mintAmount:      1000,
			burnAmount:      -100,
			expectedPanic:   true,
			expectedMessage: "invalid amount",
		},
		{
			name:            "Fail burn more than balance",
			caller:          govStakerAddress,
			from:            govStakerAddress,
			mintAmount:      100,
			burnAmount:      10000,
			expectedPanic:   true,
			expectedMessage: "insufficient balance",
		},
		{
			name:            "Fail burn by unauthorized caller",
			caller:          adminAddr,
			from:            govStakerAddress,
			mintAmount:      1000,
			burnAmount:      100,
			expectedPanic:   true,
			expectedMessage: "unauthorized: caller g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 is not gov_staker",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			initialSupply := TotalSupply()
			testing.SetRealm(testing.NewUserRealm(govStakerAddress))
			Mint(cross, govStakerAddress, tc.mintAmount)
			initialBalance := BalanceOf(tc.from)

			// when & then
			if tc.expectedPanic {
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(tc.caller))
					Burn(cross, tc.from, tc.burnAmount)
				})
			} else {
				testing.SetRealm(testing.NewUserRealm(tc.caller))
				Burn(cross, tc.from, tc.burnAmount)

				expectedBalance := initialBalance - tc.burnAmount
				actualBalance := BalanceOf(tc.from)
				uassert.Equal(t, expectedBalance, actualBalance)

				expectedSupply := initialSupply + tc.mintAmount - tc.burnAmount
				actualSupply := TotalSupply()
				uassert.Equal(t, expectedSupply, actualSupply)
			}
		})
	}
}

func TestXgns_VotingSupply(t *testing.T) {
	tests := []struct {
		name                 string
		govStakerAmount      int64
		launchpadAmount      int64
		expectedVotingSupply int64
	}{
		{
			name:                 "Normal case with both balances",
			govStakerAmount:      800,
			launchpadAmount:      200,
			expectedVotingSupply: 800,
		},
		{
			name:                 "Zero launchpad balance",
			govStakerAmount:      1000,
			launchpadAmount:      0,
			expectedVotingSupply: 1000,
		},
		{
			name:                 "Zero total supply",
			govStakerAmount:      0,
			launchpadAmount:      0,
			expectedVotingSupply: 0,
		},
		{
			name:                 "Only launchpad has balance",
			govStakerAmount:      0,
			launchpadAmount:      500,
			expectedVotingSupply: 0,
		},
		{
			name:                 "Launchpad balance equals total supply",
			govStakerAmount:      0,
			launchpadAmount:      1000,
			expectedVotingSupply: 0,
		},
		{
			name:                 "Multiple mints with large amounts",
			govStakerAmount:      1000000000,
			launchpadAmount:      500000000,
			expectedVotingSupply: 1000000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.govStakerAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, govStakerAddress, tc.govStakerAmount)
			}

			if tc.launchpadAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, launchpadAddress, tc.launchpadAmount)
			}

			// when
			actualVotingSupply := VotingSupply()

			// then
			uassert.Equal(t, tc.expectedVotingSupply, actualVotingSupply)
		})
	}
}

func TestXgns_BalanceOf(t *testing.T) {
	tests := []struct {
		name            string
		targetAddr      address
		mintAmount      int64
		expectedBalance int64
	}{
		{
			name:            "Zero balance for admin",
			targetAddr:      adminAddr,
			mintAmount:      0,
			expectedBalance: 0,
		},
		{
			name:            "Balance after minting",
			targetAddr:      govStakerAddress,
			mintAmount:      500,
			expectedBalance: 500,
		},
		{
			name:            "Empty address returns zero balance",
			targetAddr:      address(""),
			mintAmount:      0,
			expectedBalance: 0,
		},
		{
			name:            "Non-existent address returns zero balance",
			targetAddr:      address("g1nonexistentaddressxxxxxxxxxxxxxxxxxxx"),
			mintAmount:      0,
			expectedBalance: 0,
		},
		{
			name:            "Balance with minimum mint amount",
			targetAddr:      govStakerAddress,
			mintAmount:      1,
			expectedBalance: 1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.mintAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, tc.targetAddr, tc.mintAmount)
			}

			// when
			actualBalance := BalanceOf(tc.targetAddr)

			// then
			uassert.Equal(t, tc.expectedBalance, actualBalance)
		})
	}
}

func TestXgns_Render(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		mintAmount     int64
		expectedResult string
		checkNonEmpty  bool
	}{
		{
			name:          "Empty path returns token home",
			path:          "",
			mintAmount:    0,
			checkNonEmpty: true,
		},
		{
			name:           "Balance path with minted tokens",
			path:           "balance/" + string(govStakerAddress),
			mintAmount:     1000,
			expectedResult: "1000\n",
		},
		{
			name:           "Invalid balance path",
			path:           "balance",
			mintAmount:     0,
			expectedResult: "404\n",
		},
		{
			name:           "Voting supply path",
			path:           "votingsupply",
			mintAmount:     1000,
			expectedResult: "1000\n",
		},
		{
			name:           "Invalid voting supply path",
			path:           "votingsupply/invalid",
			mintAmount:     0,
			// ignore extra paths
			expectedResult: "0\n",
		},
		{
			name:           "Invalid path returns 404",
			path:           "invalid/path",
			mintAmount:     0,
			expectedResult: "404\n",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.mintAmount > 0 {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, govStakerAddress, tc.mintAmount)
			}

			// when
			result := Render(tc.path)

			// then
			if tc.checkNonEmpty {
				if result == "" {
					t.Errorf("[%s] expected non-empty result", tc.name)
				}
			} else {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestXgns_Halted(t *testing.T) {
	tests := []struct {
		name            string
		operation       string
		setupMint       bool
		expectedMessage string
	}{
		{
			name:            "Halted Mint by gov staker",
			operation:       "Mint",
			setupMint:       false,
			expectedMessage: "halted: xgns",
		},
		{
			name:            "Halted Burn by gov staker",
			operation:       "Burn",
			setupMint:       true,
			expectedMessage: "halted: xgns",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)
			resetHalt(t)

			// given
			if tc.setupMint {
				testing.SetRealm(testing.NewUserRealm(govStakerAddress))
				Mint(cross, govStakerAddress, 100)

				Mint(cross, launchpadAddress, 100)
			}

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			halt.SetOperationStatus(cross, halt.OpTypeXGns, true)

			// when & then
			switch tc.operation {
			case "Mint":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(govStakerAddress))
					Mint(cross, govStakerAddress, 100)
				})
			case "Burn":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(govStakerAddress))
					Burn(cross, govStakerAddress, 50)
				})
			}
		})
	}
}

// TestXgns_MintThenBurnAll tests minting and then burning the entire amount
func TestXgns_MintThenBurnAll(t *testing.T) {
	tests := []struct {
		name                 string
		mintAmount           int64
		burnAmount           int64
		expectedFinalBalance int64
		expectedFinalSupply  int64
	}{
		{
			name:                 "Mint and burn entire amount",
			mintAmount:           1000,
			burnAmount:           1000,
			expectedFinalBalance: 0,
			expectedFinalSupply:  0,
		},
		{
			name:                 "Mint large amount and burn all",
			mintAmount:           1000000000,
			burnAmount:           1000000000,
			expectedFinalBalance: 0,
			expectedFinalSupply:  0,
		},
		{
			name:                 "Mint minimum and burn all",
			mintAmount:           1,
			burnAmount:           1,
			expectedFinalBalance: 0,
			expectedFinalSupply:  0,
		},
		{
			name:                 "Mint and burn partial amount",
			mintAmount:           1000,
			burnAmount:           600,
			expectedFinalBalance: 400,
			expectedFinalSupply:  400,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)
			resetHalt(t)

			// given - mint tokens
			testing.SetRealm(testing.NewUserRealm(govStakerAddress))
			Mint(cross, govStakerAddress, tc.mintAmount)

			// verify mint
			uassert.Equal(t, tc.mintAmount, BalanceOf(govStakerAddress))
			uassert.Equal(t, tc.mintAmount, TotalSupply())

			// when - burn tokens
			testing.SetRealm(testing.NewUserRealm(govStakerAddress))
			Burn(cross, govStakerAddress, tc.burnAmount)

			// then
			uassert.Equal(t, tc.expectedFinalBalance, BalanceOf(govStakerAddress))
			uassert.Equal(t, tc.expectedFinalSupply, TotalSupply())
		})
	}
}

// TestXgns_MultipleAddressMintVotingSupply tests VotingSupply with multiple addresses
func TestXgns_MultipleAddressMintVotingSupply(t *testing.T) {
	user1 := testutils.TestAddress("user1")
	user2 := testutils.TestAddress("user2")
	user3 := testutils.TestAddress("user3")

	tests := []struct {
		name                 string
		mintToGovStaker      int64
		mintToLaunchpad      int64
		mintToUser1          int64
		mintToUser2          int64
		mintToUser3          int64
		expectedTotalSupply  int64
		expectedVotingSupply int64
	}{
		{
			name:                 "Multiple users with no launchpad",
			mintToGovStaker:      1000,
			mintToLaunchpad:      0,
			mintToUser1:          500,
			mintToUser2:          300,
			mintToUser3:          200,
			expectedTotalSupply:  2000,
			expectedVotingSupply: 2000,
		},
		{
			name:                 "Multiple users with launchpad",
			mintToGovStaker:      1000,
			mintToLaunchpad:      500,
			mintToUser1:          300,
			mintToUser2:          200,
			mintToUser3:          0,
			expectedTotalSupply:  2000,
			expectedVotingSupply: 1500, // 2000 - 500 (launchpad)
		},
		{
			name:                 "Large amounts distributed",
			mintToGovStaker:      1000000000,
			mintToLaunchpad:      500000000,
			mintToUser1:          200000000,
			mintToUser2:          100000000,
			mintToUser3:          50000000,
			expectedTotalSupply:  1850000000,
			expectedVotingSupply: 1350000000, // 1850000000 - 500000000
		},
		{
			name:                 "Only launchpad has tokens",
			mintToGovStaker:      0,
			mintToLaunchpad:      1000,
			mintToUser1:          0,
			mintToUser2:          0,
			mintToUser3:          0,
			expectedTotalSupply:  1000,
			expectedVotingSupply: 0, // all in launchpad
		},
		{
			name:                 "Equal distribution across users",
			mintToGovStaker:      100,
			mintToLaunchpad:      100,
			mintToUser1:          100,
			mintToUser2:          100,
			mintToUser3:          100,
			expectedTotalSupply:  500,
			expectedVotingSupply: 400, // 500 - 100 (launchpad)
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)
			resetHalt(t)

			// given - mint to various addresses
			testing.SetRealm(testing.NewUserRealm(govStakerAddress))

			if tc.mintToGovStaker > 0 {
				Mint(cross, govStakerAddress, tc.mintToGovStaker)
			}
			if tc.mintToLaunchpad > 0 {
				Mint(cross, launchpadAddress, tc.mintToLaunchpad)
			}
			if tc.mintToUser1 > 0 {
				Mint(cross, user1, tc.mintToUser1)
			}
			if tc.mintToUser2 > 0 {
				Mint(cross, user2, tc.mintToUser2)
			}
			if tc.mintToUser3 > 0 {
				Mint(cross, user3, tc.mintToUser3)
			}

			// when
			actualTotalSupply := TotalSupply()
			actualVotingSupply := VotingSupply()

			// then
			uassert.Equal(t, tc.expectedTotalSupply, actualTotalSupply)
			uassert.Equal(t, tc.expectedVotingSupply, actualVotingSupply)

			// verify individual balances
			uassert.Equal(t, tc.mintToGovStaker, BalanceOf(govStakerAddress))
			uassert.Equal(t, tc.mintToLaunchpad, BalanceOf(launchpadAddress))
			uassert.Equal(t, tc.mintToUser1, BalanceOf(user1))
			uassert.Equal(t, tc.mintToUser2, BalanceOf(user2))
			uassert.Equal(t, tc.mintToUser3, BalanceOf(user3))
		})
	}
}

// TestXgns_SequentialMintBurn tests sequential mint and burn operations
func TestXgns_SequentialMintBurn(t *testing.T) {
	type operation struct {
		opType string // "mint" or "burn"
		target address
		amount int64
	}

	tests := []struct {
		name                  string
		operations            []operation
		expectedFinalSupply   int64
		expectedGovBalance    int64
		expectedLaunchBalance int64
	}{
		{
			name: "Alternating mint and burn",
			operations: []operation{
				{"mint", govStakerAddress, 1000},
				{"burn", govStakerAddress, 200},
				{"mint", govStakerAddress, 500},
				{"burn", govStakerAddress, 300},
			},
			expectedFinalSupply:   1000,
			expectedGovBalance:    1000,
			expectedLaunchBalance: 0,
		},
		{
			name: "Multiple mints then burns",
			operations: []operation{
				{"mint", govStakerAddress, 100},
				{"mint", govStakerAddress, 200},
				{"mint", govStakerAddress, 300},
				{"burn", govStakerAddress, 150},
				{"burn", govStakerAddress, 250},
			},
			expectedFinalSupply:   200,
			expectedGovBalance:    200,
			expectedLaunchBalance: 0,
		},
		{
			name: "Cross-address operations",
			operations: []operation{
				{"mint", govStakerAddress, 1000},
				{"mint", launchpadAddress, 500},
				{"burn", govStakerAddress, 200},
				{"mint", govStakerAddress, 100},
				{"burn", launchpadAddress, 100},
			},
			expectedFinalSupply:   1300,
			expectedGovBalance:    900,
			expectedLaunchBalance: 400,
		},
		{
			name: "Burn all then mint again",
			operations: []operation{
				{"mint", govStakerAddress, 1000},
				{"burn", govStakerAddress, 1000},
				{"mint", govStakerAddress, 500},
			},
			expectedFinalSupply:   500,
			expectedGovBalance:    500,
			expectedLaunchBalance: 0,
		},
		{
			name: "Complex sequence with multiple addresses",
			operations: []operation{
				{"mint", govStakerAddress, 1000},
				{"mint", launchpadAddress, 2000},
				{"burn", govStakerAddress, 500},
				{"mint", govStakerAddress, 300},
				{"burn", launchpadAddress, 1000},
				{"mint", launchpadAddress, 500},
			},
			expectedFinalSupply:   2300,
			expectedGovBalance:    800,
			expectedLaunchBalance: 1500,
		},
		{
			name: "Small incremental operations",
			operations: []operation{
				{"mint", govStakerAddress, 1},
				{"mint", govStakerAddress, 1},
				{"mint", govStakerAddress, 1},
				{"burn", govStakerAddress, 1},
				{"mint", govStakerAddress, 1},
				{"burn", govStakerAddress, 1},
			},
			expectedFinalSupply:   2,
			expectedGovBalance:    2,
			expectedLaunchBalance: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)
			resetHalt(t)

			// given & when - execute operations sequentially
			testing.SetRealm(testing.NewUserRealm(govStakerAddress))

			for _, op := range tc.operations {
				switch op.opType {
				case "mint":
					Mint(cross, op.target, op.amount)
				case "burn":
					Burn(cross, op.target, op.amount)
				}
			}

			// then
			uassert.Equal(t, tc.expectedFinalSupply, TotalSupply())
			uassert.Equal(t, tc.expectedGovBalance, BalanceOf(govStakerAddress))
			uassert.Equal(t, tc.expectedLaunchBalance, BalanceOf(launchpadAddress))

			// verify voting supply calculation
			expectedVotingSupply := tc.expectedFinalSupply - tc.expectedLaunchBalance
			uassert.Equal(t, expectedVotingSupply, VotingSupply())
		})
	}
}

// Helper functions

func getContractAddress(roleName string) address {
	addr, exists := access.GetAddress(roleName)
	if !exists {
		return rbac.DefaultRoleAddresses[prbac.SystemRole(roleName)]
	}
	return addr
}

func cleanup(t *testing.T) {
	admin = ownable.NewWithAddress(testutils.TestAddress("admin"))
	token, ledger = grc20.NewToken("XGNS", "xGNS", 6)
}

func resetHalt(t *testing.T) {
	t.Helper()
	if adminAddr, ok := access.GetAddress(prbac.ROLE_ADMIN.String()); ok {
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		halt.SetOperationStatus(cross, halt.OpTypeXGns, false)
	}
}
