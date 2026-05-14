package v1

import (
	"strconv"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
)

func TestMultiSwap(t *testing.T) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	tests := []struct {
		name            string
		setupFn         func(*TestEnv)
		params          SwapParams
		numPools        int
		swapPath        string
		expectedFirstIn string
		expectedLastOut string
		expectError     bool
	}{
		{
			name: "single hop swap ATOM -> ATONE",
			setupFn: func(env *TestEnv) {
				env.GivenPoolCreated(atomPath, atonePath, 3000, "79228162514264337593543950336").
					AndPositionMinted().
					AndUserFundedAndApproved(user1Addr, routerAddr, atomPath, atonePath)
			},
			params: NewSwapParams().
				Recipient(alice).
				TokenIn(atomPath).
				TokenOut(atonePath).
				Fee(3000).
				ExactInput("100").
				Build(),
			numPools:        1,
			swapPath:        "",
			expectedFirstIn: "100",
			expectedLastOut: "98",
			expectError:     false,
		},
		// {
		// 	name: "multi hop swap (ATOM -> ATONE -> SOL)",
		// 	setupFn: func(t *testing.T) {
		// 		// ATOM -> ATONE
		// 		CreatePoolWithoutFee(t)
		// 		MakeMintPositionWithoutFee(t)

		// 		// ATONE -> SOL
		// 		CreateSecondPoolWithoutFee(t)
		// 		MakeSecondMintPositionWithoutFee(t)

		// 		testing.SetRealm(user1Realm)
		// 		atom.Approve(cross, routerAddr, maxApprove)
		// 		atone.Approve(cross, routerAddr, maxApprove)
		// 		sol.Approve(cross, routerAddr, maxApprove)
		// 		TokenFaucet(t, atomPath, user1Addr)
		// 	},
		// 	params: SwapParams{
		// 		recipient: alice,
		// 		SingleSwapParams: SingleSwapParams{
		// 			tokenIn:         atomPath,
		// 			tokenOut:        atonePath,
		// 			fee:             3000,
		// 			amountSpecified: i256.MustFromDecimal("100"),
		// 		},
		// 	},
		// 	numPools:        2,
		// 	swapPath:        "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:3000",
		// 	expectedFirstIn: "100",
		// 	expectedLastOut: "96",
		// 	expectError:     false,
		// },
		// {
		// 	name: "multi hop swap with exact output",
		// 	setupFn: func(t *testing.T) {
		// 		// ATOM -> ATONE -> SOL
		// 		CreatePoolWithoutFee(t)
		// 		MakeMintPositionWithoutFee(t)
		// 		CreateSecondPoolWithoutFee(t)
		// 		MakeSecondMintPositionWithoutFee(t)

		// 		testing.SetRealm(user1Realm)
		// 		atom.Approve(cross, routerAddr, maxApprove)
		// 		atone.Approve(cross, routerAddr, maxApprove)
		// 		sol.Approve(cross, routerAddr, maxApprove)
		// 		TokenFaucet(t, atomPath, user1Addr)
		// 	},
		// 	params: SwapParams{
		// 		recipient: alice,
		// 		SingleSwapParams: SingleSwapParams{
		// 			tokenIn:         atomPath,
		// 			tokenOut:        atonePath,
		// 			fee:             3000,
		// 			amountSpecified: i256.MustFromDecimal("-96"),
		// 		},
		// 	},
		// 	numPools:        2,
		// 	swapPath:        "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/sol:3000",
		// 	expectedFirstIn: "98",
		// 	expectedLastOut: "94",
		// 	expectError:     false,
		// },
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			firstAmountIn, lastAmountOut := router.multiSwap(
				tt.params,
				tt.numPools,
				tt.swapPath,
			)

			uassert.Equal(t, strconv.FormatInt(firstAmountIn, 10), tt.expectedFirstIn)
			uassert.Equal(t, strconv.FormatInt(lastAmountOut, 10), tt.expectedLastOut)
		})
	}
}
