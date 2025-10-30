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
			expectedMessage: "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker",
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

func TestXgns_MintByLaunchPad(t *testing.T) {
	tests := []struct {
		name            string
		realmPath       string
		to              address
		setupAmount     int64
		amount          int64
		expectedPanic   bool
		expectedMessage string
	}{
		{
			name:      "Success mint by launchpad",
			realmPath: "gno.land/r/gnoswap/launchpad",
			to:        launchpadAddress,
			amount:    500,
		},
		{
			name:      "Success mint with zero amount",
			realmPath: "gno.land/r/gnoswap/launchpad",
			to:        launchpadAddress,
			amount:    0,
		},
		{
			name:      "Success mint with minimum amount",
			realmPath: "gno.land/r/gnoswap/launchpad",
			to:        launchpadAddress,
			amount:    1,
		},
		{
			name:            "Fail mint with negative amount",
			realmPath:       "gno.land/r/gnoswap/launchpad",
			to:              launchpadAddress,
			amount:          -100,
			expectedPanic:   true,
			expectedMessage: "invalid amount",
		},
		{
			name:            "Fail mint causing total supply overflow",
			realmPath:       "gno.land/r/gnoswap/launchpad",
			to:              launchpadAddress,
			setupAmount:     math.MaxInt64 - 100,
			amount:          200,
			expectedPanic:   true,
			expectedMessage: "mint overflow",
		},
		{
			name:            "Fail mint by unauthorized caller",
			realmPath:       "gno.land/r/unauthorized",
			to:              launchpadAddress,
			amount:          100,
			expectedPanic:   true,
			expectedMessage: "unauthorized: caller g1hx55pprrg3zhqchz042hsrfg646ydua6x7ssz9 is not launchpad",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			if tc.setupAmount > 0 {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
				MintByLaunchPad(cross, launchpadAddress, tc.setupAmount)
			}

			initialSupply := TotalSupply()
			initialBalance := BalanceOf(tc.to)

			// when & then
			if tc.expectedPanic {
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewCodeRealm(tc.realmPath))
					MintByLaunchPad(cross, tc.to, tc.amount)
				})
			} else {
				testing.SetRealm(testing.NewCodeRealm(tc.realmPath))
				MintByLaunchPad(cross, tc.to, tc.amount)

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
			expectedMessage: "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker",
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

func TestXgns_BurnByLaunchPad(t *testing.T) {
	tests := []struct {
		name            string
		realmPath       string
		from            address
		mintAmount      int64
		burnAmount      int64
		expectedPanic   bool
		expectedMessage string
	}{
		{
			name:       "Success burn by launchpad",
			realmPath:  "gno.land/r/gnoswap/launchpad",
			from:       launchpadAddress,
			mintAmount: 1000,
			burnAmount: 200,
		},
		{
			name:       "Success burn with zero amount",
			realmPath:  "gno.land/r/gnoswap/launchpad",
			from:       launchpadAddress,
			mintAmount: 1000,
			burnAmount: 0,
		},
		{
			name:       "Success burn with minimum amount",
			realmPath:  "gno.land/r/gnoswap/launchpad",
			from:       launchpadAddress,
			mintAmount: 10,
			burnAmount: 1,
		},
		{
			name:            "Fail burn with negative amount",
			realmPath:       "gno.land/r/gnoswap/launchpad",
			from:            launchpadAddress,
			mintAmount:      1000,
			burnAmount:      -100,
			expectedPanic:   true,
			expectedMessage: "invalid amount",
		},
		{
			name:            "Fail burn more than balance",
			realmPath:       "gno.land/r/gnoswap/launchpad",
			from:            launchpadAddress,
			mintAmount:      100,
			burnAmount:      10000,
			expectedPanic:   true,
			expectedMessage: "insufficient balance",
		},
		{
			name:            "Fail burn by unauthorized caller",
			realmPath:       "gno.land/r/unauthorized",
			from:            launchpadAddress,
			mintAmount:      1000,
			burnAmount:      100,
			expectedPanic:   true,
			expectedMessage: "unauthorized: caller g1hx55pprrg3zhqchz042hsrfg646ydua6x7ssz9 is not launchpad",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cleanup(t)

			// given
			initialSupply := TotalSupply()
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
			MintByLaunchPad(cross, launchpadAddress, tc.mintAmount)
			initialBalance := BalanceOf(tc.from)

			// when & then
			if tc.expectedPanic {
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewCodeRealm(tc.realmPath))
					BurnByLaunchPad(cross, tc.from, tc.burnAmount)
				})
			} else {
				testing.SetRealm(testing.NewCodeRealm(tc.realmPath))
				BurnByLaunchPad(cross, tc.from, tc.burnAmount)

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
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
				MintByLaunchPad(cross, launchpadAddress, tc.launchpadAmount)
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
			name:            "Halted MintByLaunchPad",
			operation:       "MintByLaunchPad",
			setupMint:       false,
			expectedMessage: "halted: xgns",
		},
		{
			name:            "Halted Burn by gov staker",
			operation:       "Burn",
			setupMint:       true,
			expectedMessage: "halted: xgns",
		},
		{
			name:            "Halted BurnByLaunchPad",
			operation:       "BurnByLaunchPad",
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

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
				MintByLaunchPad(cross, launchpadAddress, 100)
			}

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			halt.SetOperationStatus(cross, halt.OpTypeXGns, 1, true)

			// when & then
			switch tc.operation {
			case "Mint":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(govStakerAddress))
					Mint(cross, govStakerAddress, 100)
				})
			case "MintByLaunchPad":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
					MintByLaunchPad(cross, launchpadAddress, 100)
				})
			case "Burn":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewUserRealm(govStakerAddress))
					Burn(cross, govStakerAddress, 50)
				})
			case "BurnByLaunchPad":
				uassert.AbortsWithMessage(t, tc.expectedMessage, func() {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
					BurnByLaunchPad(cross, launchpadAddress, 50)
				})
			}
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
		halt.SetOperationStatus(cross, halt.OpTypeXGns, 1, false)
	}
}
