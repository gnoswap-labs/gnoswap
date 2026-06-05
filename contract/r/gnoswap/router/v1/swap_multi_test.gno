package v1

import (
	"strconv"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
)

func TestMultiSwap(cur realm, t *testing.T) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	tests := []struct {
		name            string
		params          SwapParams
		numPools        int
		swapPath        string
		expectedFirstIn string
		expectedLastOut string
		expectError     bool
	}{
		{
			name: "single hop swap BAR -> BAZ",
			params: NewSwapParams().
				Recipient(alice).
				TokenIn(barPath).
				TokenOut(bazPath).
				Fee(3000).
				ExactInput("100").
				Build(),
			numPools:        1,
			swapPath:        "",
			expectedFirstIn: "100",
			expectedLastOut: "98",
			expectError:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			initPoolTest(cur, t)
			initRouterTest(cur, t)

			env := NewTestEnv(cur, t)
			testing.SetRealm(adminRealm)
			env.GivenPoolCreated(cur, barPath, bazPath, 3000, "79228162514264337593543950336").
				AndPositionMinted(cur)
			testing.SetRealm(testing.NewUserRealm(user1Addr))
			env.AndUserFundedAndApproved(cur, user1Addr, routerAddr, barPath, bazPath)

			router := mockRouter()
			multiSwapFn := func(cur realm) (int64, int64) {
				return router.multiSwap(0, cur, tt.params, tt.numPools, tt.swapPath)
			}

			// Run the swap as the funded user so the swap callback's payer
			// (cur.Previous()) resolves to user1 and the pool can pull the
			// input token. Mirrors TestSingleSwap.
			testing.SetRealm(testing.NewUserRealm(user1Addr))
			common.Approve(cross(cur), tt.params.tokenIn, poolAddr, maxApprove)
			common.Approve(cross(cur), tt.params.tokenOut, poolAddr, maxApprove)

			firstAmountIn, lastAmountOut := multiSwapFn(cross(cur))

			uassert.Equal(t, strconv.FormatInt(firstAmountIn, 10), tt.expectedFirstIn)
			uassert.Equal(t, strconv.FormatInt(lastAmountOut, 10), tt.expectedLastOut)
		})
	}
}
