package v1

import (
	"chain"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
)

func TestSwapCallback_Pay(t *testing.T) {
	tests := []struct {
		name                            string
		poolInfo                        swapPaidCreatePoolParams
		positionInfo                    []swapPaidMintPositionParams
		swapInfo                        swapPaidSwapParams
		expectedToken0PoolBalanceChange int64
		expectedToken1PoolBalanceChange int64
		expectedHasPanic                bool
		expectedHasPanicMessage         string
	}{
		{
			name: "zero for one swap is success for paid amount equal to specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               true,
				sqrtPriceLimitX96:        MIN_PRICE,
				callbackSendToken0Amount: 1000, // equal to specified amount
				callbackSendToken1Amount: 0,
			},
			expectedToken0PoolBalanceChange: 1000,
			expectedToken1PoolBalanceChange: -998,
		},
		{
			name: "zero for one swap is success for paid amount greater than specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               true,
				sqrtPriceLimitX96:        MIN_PRICE,
				callbackSendToken0Amount: 1001, // greater than specified amount
				callbackSendToken1Amount: 0,
			},
			expectedToken0PoolBalanceChange: 1000,
			expectedToken1PoolBalanceChange: -998,
		},
		{
			name: "zero for one swap is failed for paid amount less than specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               true,
				sqrtPriceLimitX96:        MIN_PRICE,
				callbackSendToken0Amount: 999, // less than specified amount
				callbackSendToken1Amount: 0,
			},
			expectedHasPanic:        true,
			expectedHasPanicMessage: "[GNOSWAP-POOL-030] insufficient payment || insufficient payment: expected 1000, received 999",
		},
		{
			name: "one for zero swap is success for paid amount equal to specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               false,
				sqrtPriceLimitX96:        MAX_PRICE,
				callbackSendToken0Amount: 0,
				callbackSendToken1Amount: 1000, // equal to specified amount
			},
			expectedToken0PoolBalanceChange: -998,
			expectedToken1PoolBalanceChange: 1000,
		},
		{
			name: "one for zero swap is success for paid amount greater than specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               false,
				sqrtPriceLimitX96:        MAX_PRICE,
				callbackSendToken0Amount: 0,
				callbackSendToken1Amount: 1001, // greater than specified amount
			},
			expectedToken0PoolBalanceChange: -998,
			expectedToken1PoolBalanceChange: 1000,
		},
		{
			name: "one for zero swap is failed for paid amount less than specified amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:               barPath,
				token1Path:               bazPath,
				specifiedAmount:          "1000",
				recipient:                adminAddr,
				payer:                    adminAddr,
				zeroForOne:               false,
				sqrtPriceLimitX96:        MAX_PRICE,
				callbackSendToken0Amount: 0,
				callbackSendToken1Amount: 999, // less than specified amount
			},
			expectedHasPanic:        true,
			expectedHasPanicMessage: "[GNOSWAP-POOL-030] insufficient payment || insufficient payment: expected 1000, received 999",
		},
		{
			name: "zero for one swap is success for partial paid amount",
			poolInfo: swapPaidCreatePoolParams{
				token0Path: barPath,
				token1Path: bazPath,
				feeTier:    FeeTier500,
			},
			positionInfo: []swapPaidMintPositionParams{
				{
					token0Path:       barPath,
					token1Path:       bazPath,
					feeTier:          FeeTier500,
					tickLower:        -200,
					tickUpper:        200,
					amount0Requested: 10000000,
					amount1Requested: 10000000,
				},
			},
			swapInfo: swapPaidSwapParams{
				token0Path:          barPath,
				token1Path:          bazPath,
				specifiedAmount:     "5000000",
				recipient:           adminAddr,
				payer:               adminAddr,
				zeroForOne:          true,
				sqrtPriceLimitX96:   common.TickMathGetSqrtRatioAtTick(-10).ToString(),
				isUseCallbackAmount: true,
			},
			expectedToken0PoolBalanceChange: 502882,
			expectedToken1PoolBalanceChange: -502378,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initSwapPaid(t)
			defer initSwapPaid(t)

			initSwapPaidCreatePool(t, barPath, bazPath, FeeTier500)
			initSwapPaidSetFeeMintPosition(t, barPath, bazPath, FeeTier500, -200, 200, 10000000, 10000000)

			token0PoolBalanceChange := int64(0)
			token1PoolBalanceChange := int64(0)

			swapFn := func() (string, string) {
				beforeToken0PoolBalance := common.BalanceOf(tt.swapInfo.token0Path, poolAddr)
				beforeToken1PoolBalance := common.BalanceOf(tt.swapInfo.token1Path, poolAddr)

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
				resultAmount0, resultAmount1 := mockInstance.Swap(
					tt.swapInfo.token0Path,
					tt.swapInfo.token1Path,
					tt.poolInfo.feeTier,
					tt.swapInfo.recipient,
					tt.swapInfo.zeroForOne,
					tt.swapInfo.specifiedAmount,
					tt.swapInfo.sqrtPriceLimitX96,
					tt.swapInfo.payer,
					func(cur realm, amount0Delta string, amount1Delta string) error {
						currentAmount0Delta := "0"
						currentAmount1Delta := "0"

						if tt.swapInfo.zeroForOne {
							currentAmount0Delta = amount0Delta
						} else {
							currentAmount1Delta = amount1Delta
						}

						if !tt.swapInfo.isUseCallbackAmount {
							currentAmount0Delta = strconv.FormatInt(tt.swapInfo.callbackSendToken0Amount, 10)
							currentAmount1Delta = strconv.FormatInt(tt.swapInfo.callbackSendToken1Amount, 10)
						}

						return swapPaidSwapCallback(
							tt.swapInfo.token0Path,
							tt.swapInfo.token1Path,
							currentAmount0Delta,
							currentAmount1Delta,
						)
					},
				)

				token0PoolBalanceChange = common.BalanceOf(tt.swapInfo.token0Path, poolAddr) - beforeToken0PoolBalance
				token1PoolBalanceChange = common.BalanceOf(tt.swapInfo.token1Path, poolAddr) - beforeToken1PoolBalance

				return resultAmount0, resultAmount1
			}

			if tt.expectedHasPanic {
				uassert.AbortsContains(t, tt.expectedHasPanicMessage, func() {
					swapFn()
				})
			} else {
				resultAmount0, resultAmount1 := swapFn()
				t.Logf("resultAmount0: %s, resultAmount1: %s", resultAmount0, resultAmount1)
				uassert.Equal(t, true, token0PoolBalanceChange >= tt.expectedToken0PoolBalanceChange)
				uassert.Equal(t, true, token1PoolBalanceChange >= tt.expectedToken1PoolBalanceChange)
			}
		})
	}
}

func swapPaidSwapCallback(
	token0Path string,
	token1Path string,
	amount0Delta string,
	amount1Delta string,
) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	amount0Int64, _ := strconv.ParseInt(amount0Delta, 10, 64)
	amount1Int64, _ := strconv.ParseInt(amount1Delta, 10, 64)

	if amount0Int64 > 0 {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Int64)
	}
	if amount1Int64 > 0 {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Int64)
	}

	return nil
}

// test helpers
func initSwapPaid(t *testing.T) {
	initPoolTest(t)
}

func initSwapPaidCreatePool(t *testing.T, token0Path, token1Path string, feeTier uint32) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	mockInstance.SetPoolCreationFee(0)

	if !mockInstance.ExistsPoolPath(GetPoolPath(token0Path, token1Path, feeTier)) {
		mockInstance.CreatePool(token0Path, token1Path, feeTier, common.TickMathGetSqrtRatioAtTick(0).ToString())
	}
}

func initSwapPaidSetFeeMintPosition(
	t *testing.T,
	token0Path,
	token1Path string,
	feeTier uint32,
	tickLower, tickUpper int32,
	amount0Requested, amount1Requested int64,
) {
	const maxTimeout int64 = 9999999999

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	testing.SetOriginSend(chain.Coins{})

	if amount0Requested > 0 {
		if common.IsGNOTNativePath(token0Path) {
			testing.SetOriginSend(chain.Coins{{common.GNOT_DENOM, amount0Requested}})
		} else {
			common.SafeGRC20Approve(cross, token0Path, poolAddr, amount0Requested)
		}
	}

	if amount1Requested > 0 {
		if common.IsGNOTNativePath(token1Path) {
			testing.SetOriginSend(chain.Coins{{common.GNOT_DENOM, amount1Requested}})
		} else {
			common.SafeGRC20Approve(cross, token1Path, poolAddr, amount1Requested)
		}
	}

	sqrtPriceX96 := mockInstance.GetSlot0SqrtPriceX96(GetPoolPath(token0Path, token1Path, feeTier))
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(tickUpper)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		uint256.NewUintFromInt64(amount0Requested),
		uint256.NewUintFromInt64(amount1Requested),
	)

	testing.SetRealm(testing.NewUserRealm(positionAddr))
	mockInstance.Mint(
		token0Path,
		token1Path,
		feeTier,
		tickLower,
		tickUpper,
		liquidity.ToString(),
		adminAddr,
	)
}

type swapPaidCreatePoolParams struct {
	token0Path string
	token1Path string
	feeTier    uint32
}

type swapPaidMintPositionParams struct {
	token0Path       string
	token1Path       string
	feeTier          uint32
	tickLower        int32
	tickUpper        int32
	amount0Requested int64
	amount1Requested int64
}

type swapPaidSwapParams struct {
	token0Path               string
	token1Path               string
	specifiedAmount          string
	recipient                address
	payer                    address
	zeroForOne               bool
	sqrtPriceLimitX96        string
	isUseCallbackAmount      bool
	callbackSendToken0Amount int64
	callbackSendToken1Amount int64
}
