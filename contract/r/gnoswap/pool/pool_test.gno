package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	// u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gns"

	// pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

// cleanupPool removes the created pool to prevent interference with other tests
func cleanupPool(t *testing.T, token0Path, token1Path string, fee uint32) {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	if pools.Has(poolPath) {
		pools.Remove(poolPath)
	}
}

func TestMint(t *testing.T) {
	var (
		fooTokenPath = "gno.land/r/onbloc/foo"
		barTokenPath = "gno.land/r/onbloc/bar"
		bazTokenPath = "gno.land/r/onbloc/baz"
	)

	fee := uint32(3000)
	recipient := testutils.TestAddress("recipient")
	tickLower := int32(-100)
	tickUpper := int32(100)
	liquidityAmount := "100000"
	authorized := positionAddr

	t.Run("unauthorized caller mint should fail", func(t *testing.T) {
		unauthorized := testutils.TestAddress("unauthorized")
		expected := "[GNOSWAP-POOL-001] caller has no permission || only position(g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5) can call, called from g148tjamj80yyrm309z7rk690an22thd2l3z8ank"

		uassert.AbortsWithMessage(t, expected, func() {
			Mint(cross, fooTokenPath, barTokenPath, fee, recipient, tickLower, tickUpper, liquidityAmount, unauthorized)
		})
	})

	t.Run("mint with 0 liquidity should fail", func(t *testing.T) {
		expected := "[GNOSWAP-POOL-010] zero liquidity"

		testing.SetRealm(posRealm)
		uassert.AbortsWithMessage(t, expected, func() {
			Mint(cross, fooTokenPath, barTokenPath, fee, recipient, tickLower, tickUpper, "0", authorized)
		})
	})

	t.Run("invalid tick range should fail", func(t *testing.T) {
		// Create pool before minting
		testing.SetRealm(adminRealm)
		SetPoolCreationFeeByAdmin(cross, 0)
		CreatePool(
			cross,
			fooTokenPath,
			barTokenPath,
			fee,
			"79228162514264337593543950337",
		)

		// Cleanup pool after test
		defer cleanupPool(t, fooTokenPath, barTokenPath, fee)

		// Try minting with invalid tick range (tickLower == tickUpper)
		expected := "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(100), tickUpper(100)"
		testing.SetRealm(posRealm)

		uassert.AbortsWithMessage(t, expected, func() {
			Mint(cross, fooTokenPath, barTokenPath, fee, recipient, 100, 100, liquidityAmount, authorized)
		})
	})

	t.Run("non-existent pool should fail", func(t *testing.T) {
		expected := "[GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000) to exist"

		testing.SetRealm(posRealm)
		uassert.AbortsWithMessage(t, expected, func() {
			Mint(cross, fooTokenPath, barTokenPath, fee, recipient, -100, 100, liquidityAmount, authorized)
		})
	})

	t.Run("successful mint", func(t *testing.T) {
		// create pool first
		testing.SetRealm(adminRealm)
		SetPoolCreationFeeByAdmin(cross, 0)
		CreatePool(
			cross,
			barTokenPath,
			bazTokenPath,
			FeeTier100,
			"79228162514264337593543950336",
		)

		// approve enough token to mint position
		bar.Approve(cross, poolAddr, maxApprove)
		baz.Approve(cross, poolAddr, maxApprove)

		beforeBalance0 := bar.BalanceOf(poolAddr)
		beforeBalance1 := baz.BalanceOf(poolAddr)

		testing.SetRealm(posRealm)
		mintAmount0, mintAmount1 := Mint(
			cross,
			barTokenPath,
			bazTokenPath,
			FeeTier100,
			positionAddr,
			int32(-100),
			int32(100),
			"10000000000",
			adminAddr,
		)
		uassert.Equal(t, mintAmount0, "49872721")
		uassert.Equal(t, mintAmount1, "49872721")

		afterBalance0 := bar.BalanceOf(poolAddr)
		afterBalance1 := baz.BalanceOf(poolAddr)
		uassert.Equal(t, int64(49872721), afterBalance0-beforeBalance0)
		uassert.Equal(t, int64(49872721), afterBalance1-beforeBalance1)
	})
}

func TestBurn(t *testing.T) {
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"

	tests := []struct {
		name             string
		liquidityAmount  string
		tickLower        int32
		tickUpper        int32
		fee              uint32
		expectedAmount0  string
		expectedAmount1  string
		expectPanic      bool
		expectedPanicMsg string
	}{
		{
			name:            "successful burn",
			liquidityAmount: "10000000000", // burn all liquidity
			tickLower:       -100,
			tickUpper:       100,
			fee:             FeeTier100,
			expectedAmount0: "49872720",
			expectedAmount1: "49872720",
		},
		{
			name:             "zero liquidity",
			liquidityAmount:  "0",
			tickLower:        -100,
			tickUpper:        100,
			fee:              FeeTier100,
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-010] zero liquidity || both liquidityDelta and current position's liquidity are zero",
		},
		{
			name:             "invalid tick range",
			liquidityAmount:  "100000",
			tickLower:        200,
			tickUpper:        100,
			expectPanic:      true,
			fee:              FeeTier100,
			expectedPanicMsg: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(200), tickUpper(100)",
		},
		{
			name:             "non-existent pool",
			liquidityAmount:  "100000",
			tickLower:        -100,
			tickUpper:        100,
			fee:              FeeTier500,
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-008] requested data not found || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500) to exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.name != "non-existent pool" {
				testing.SetRealm(adminRealm)
				SetPoolCreationFeeByAdmin(cross, 0)
				CreatePool(
					cross,
					barTokenPath,
					bazTokenPath,
					tt.fee,
					"79228162514264337593543950336",
				)
				defer cleanupPool(t, barTokenPath, bazTokenPath, tt.fee)
			}

			testing.SetRealm(posRealm)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedPanicMsg, func() {
					Burn(
						cross,
						barTokenPath,
						bazTokenPath,
						tt.fee,
						tt.tickLower,
						tt.tickUpper,
						tt.liquidityAmount,
					)
				})
			} else {
				// need to add liquidity first
				if tt.name == "successful burn" {
					// Setup tokens for position owner
					testing.SetOriginCaller(adminAddr)
					newCoins := std.Coins{{"ugnot", int64(10000000000)}}
					testing.IssueCoins(adminAddr, newCoins)
					testing.SetOriginSend(newCoins)
					banker := std.NewBanker(std.BankerTypeRealmSend)
					banker.SendCoins(adminAddr, consts.WUGNOT_ADDR, newCoins)
					wugnot.Deposit(cross)

					// approve enough token to mint position
					bar.Approve(cross, poolAddr, maxApprove)
					baz.Approve(cross, poolAddr, maxApprove)

					testing.SetRealm(posRealm)
					Mint(
						cross,
						barTokenPath,
						bazTokenPath,
						tt.fee,
						positionAddr,
						tt.tickLower,
						tt.tickUpper,
						tt.liquidityAmount,
						adminAddr,
					)
				}

				amount0, amount1 := Burn(
					cross,
					barTokenPath,
					bazTokenPath,
					tt.fee,
					tt.tickLower,
					tt.tickUpper,
					tt.liquidityAmount,
				)

				if amount0 != tt.expectedAmount0 {
					t.Errorf("expected amount0 %s, got %s", tt.expectedAmount0, amount0)
				}
				if amount1 != tt.expectedAmount1 {
					t.Errorf("expected amount1 %s, got %s", tt.expectedAmount1, amount1)
				}

				pool := GetPool(barTokenPath, bazTokenPath, FeeTier100)
				posKey := getPositionKey(positionAddr, tt.tickLower, tt.tickUpper)
				newPosition := pool.mustGetPosition(posKey)
				if newPosition.tokensOwed0.IsZero() {
					t.Error("expected tokensOwed0 to be updated")
				}
				if newPosition.tokensOwed1.IsZero() {
					t.Error("expected tokensOwed1 to be updated")
				}
			}
		})
	}
}

func TestCollect(t *testing.T) {
	positionOwner := adminAddr

	tests := []struct {
		name             string
		tokenPath0       string
		tokenPath1       string
		feeTier          uint32
		recipient        std.Address
		tickLower        int32
		tickUpper        int32
		amount0Requested string
		amount1Requested string
		expectedAmount0  string
		expectedAmount1  string
		expectPanic      bool
		expectedPanicMsg string
	}{
		{
			name:             "successful collect full amount",
			tokenPath0:       wugnotPath,
			tokenPath1:       gnsPath,
			feeTier:          FeeTier10000,
			recipient:        positionOwner,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100",
			amount1Requested: "100",
			expectedAmount0:  "0",
			expectedAmount1:  "0",
		},
		// {
		// 	name:             "partial collect due to pool balance",
		// 	tokenPath0:       wugnotPath,
		// 	tokenPath1:       gnsPath,
		// 	feeTier:          FeeTier10000,
		// 	recipient:        positionOwner,
		// 	tickLower:        -200,
		// 	tickUpper:        200,
		// 	amount0Requested: "1000",
		// 	amount1Requested: "0",
		// 	expectedAmount0:  "1000",
		// 	expectedAmount1:  "0",
		// },
		// {
		// 	name:             "partial collect due to tokensOwed limit",
		// 	tokenPath0:       wugnotPath,
		// 	tokenPath1:       gnsPath,
		// 	feeTier:          FeeTier10000,
		// 	recipient:        positionOwner,
		// 	tickLower:        -200,
		// 	tickUpper:        200,
		// 	amount0Requested: "18998",
		// 	amount1Requested: "600",
		// 	expectedAmount0:  "18998",
		// 	expectedAmount1:  "0",
		// },
		{
			name:             "collect with zero requested amount",
			tokenPath0:       wugnotPath,
			tokenPath1:       gnsPath,
			feeTier:          FeeTier10000,
			recipient:        positionOwner,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "0",
			amount1Requested: "0",
			expectedAmount0:  "0",
			expectedAmount1:  "0",
		},
		{
			name:             "panic when position does not exist",
			tokenPath0:       wugnotPath,
			tokenPath1:       gnsPath,
			feeTier:          FeeTier10000,
			recipient:        positionOwner,
			tickLower:        -400,
			tickUpper:        400,
			amount0Requested: "500",
			amount1Requested: "300",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-008] requested data not found || positionKey(ZzE3MjkwY3d2bXJhcHZwODY5eGZuaGhhd2E4c205ZWRwdWZ6YXQ3ZF9fLTQwMF9fNDAw) does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Pool Creation
			testing.SetRealm(adminRealm)
			SetPoolCreationFeeByAdmin(cross, 0)
			if !DoesPoolPathExist(GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
				CreatePool(cross, tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
			}

			if tt.expectPanic {
				testing.SetRealm(posRealm)
				uassert.AbortsWithMessage(t, tt.expectedPanicMsg, func() {
					Collect(
						cross,
						tt.tokenPath0,
						tt.tokenPath1,
						tt.feeTier,
						tt.recipient,
						tt.tickLower,
						tt.tickUpper,
						tt.amount0Requested,
						tt.amount1Requested,
					)
				})
			} else {
				// Setup tokens for position owner
				testing.SetOriginCaller(positionOwner)
				newCoins := std.Coins{{"ugnot", int64(10000000000)}}
				testing.IssueCoins(positionOwner, newCoins)
				testing.SetOriginSend(newCoins)
				banker := std.NewBanker(std.BankerTypeRealmSend)
				banker.SendCoins(positionOwner, consts.WUGNOT_ADDR, newCoins)
				wugnot.Deposit(cross)
				wugnot.Approve(cross, poolAddr, maxApprove)
				gns.Approve(cross, poolAddr, maxApprove)

				testing.SetRealm(posRealm)
				Mint(
					cross,
					tt.tokenPath0,
					tt.tokenPath1,
					tt.feeTier,
					tt.recipient,
					tt.tickLower,
					tt.tickUpper,
					"100000000",
					positionOwner,
				)

				// Verify position exists
				pool := GetPool(tt.tokenPath0, tt.tokenPath1, tt.feeTier)
				posKey := getPositionKey(tt.recipient, tt.tickLower, tt.tickUpper)
				pool.mustGetPosition(posKey)

				// Setup for swap
				testing.SetOriginCaller(positionOwner)
				wugnot.Transfer(cross, routerAddr, 20000000)
				gns.Transfer(cross, routerAddr, 20000000)

				// Perform swap
				testing.SetRealm(rouRealm)
				wugnot.Approve(cross, poolAddr, maxApprove)
				Swap(
					cross,
					tt.tokenPath0,
					tt.tokenPath1,
					tt.feeTier,
					tt.recipient,
					true,
					"1000000",
					"3945129629379410362911094631",
					tt.recipient,
				)
				testing.SkipHeights(1)

				// Collect
				testing.SetRealm(posRealm)
				collectedAmount0, collectedAmount1 := Collect(
					cross,
					tt.tokenPath0,
					tt.tokenPath1,
					tt.feeTier,
					tt.recipient,
					tt.tickLower,
					tt.tickUpper,
					tt.amount0Requested,
					tt.amount1Requested,
				)

				uassert.Equal(t, tt.expectedAmount0, collectedAmount0)
				uassert.Equal(t, tt.expectedAmount1, collectedAmount1)
			}
		})
	}
}

// func TestCollectProtocolByAdmin(t *testing.T) {
// 	positionOwner := adminAddr

// 	tests := []struct {
// 		name             string
// 		tokenPath0       string
// 		tokenPath1       string
// 		feeTier          uint32
// 		recipient        std.Address
// 		tickLower        int32
// 		tickUpper        int32
// 		amount0Requested string
// 		amount1Requested string
// 		feeProtocol0     uint8
// 		feeProtocol1     uint8
// 		expectedAmount0  string
// 		expectedAmount1  string
// 		expectPanic      bool
// 	}{
// 		{
// 			name:             "failure - not admin address",
// 			tokenPath0:       wugnotPath,
// 			tokenPath1:       gnsPath,
// 			feeTier:          FeeTier500,
// 			recipient:        alice,
// 			tickLower:        -200,
// 			tickUpper:        200,
// 			amount0Requested: "100",
// 			amount1Requested: "100",
// 			feeProtocol0:     10,
// 			feeProtocol1:     10,
// 			expectedAmount0:  "0",
// 			expectedAmount1:  "0",
// 			expectPanic:      true,
// 		},
// 		{
// 			name:             "failure - collect fee amount is zero",
// 			tokenPath0:       wugnotPath,
// 			tokenPath1:       gnsPath,
// 			feeTier:          FeeTier500,
// 			recipient:        positionOwner,
// 			tickLower:        -200,
// 			tickUpper:        200,
// 			amount0Requested: "0",
// 			amount1Requested: "0",
// 			expectedAmount0:  "0",
// 			expectedAmount1:  "0",
// 		},
// 		{
// 			name:             "successful collect fee amount",
// 			tokenPath0:       wugnotPath,
// 			tokenPath1:       gnsPath,
// 			feeTier:          FeeTier500,
// 			recipient:        positionOwner,
// 			tickLower:        -200,
// 			tickUpper:        200,
// 			amount0Requested: "100",
// 			amount1Requested: "100",
// 			expectedAmount0:  "100",
// 			expectedAmount1:  "0",
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			// Pool Creation
// 			testing.SetRealm(std.NewUserRealm(positionOwner))
// 			SetPoolCreationFeeByAdmin(cross, 0)
// 			if !DoesPoolPathExist(GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
// 				CreatePool(cross, tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
// 			}

// 			if tt.feeProtocol0 != 0 || tt.feeProtocol1 != 0 {
// 				pool := GetPool(tt.tokenPath0, tt.tokenPath1, tt.feeTier)
// 				SetFeeProtocolByAdmin(cross, tt.feeProtocol0, tt.feeProtocol1)
// 				uassert.Equal(t, tt.feeProtocol0, pool.Slot0FeeProtocol()%16)
// 				uassert.Equal(t, tt.feeProtocol1, pool.Slot0FeeProtocol()>>4)
// 			}
// 			testing.SetOriginCaller(positionOwner)
// 			newCoins := std.Coins{{"ugnot", int64(10000000000)}}
// 			testing.IssueCoins(positionOwner, newCoins)
// 			testing.SetOriginSend(newCoins)
// 			banker := std.NewBanker(std.BankerTypeRealmSend)
// 			banker.SendCoins(positionOwner, consts.WUGNOT_ADDR, newCoins)
// 			wugnot.Deposit(cross)
// 			if tt.recipient != positionOwner {
// 				wugnot.Transfer(cross, tt.recipient, 10000000000)
// 			}

// 			testing.SetRealm(std.NewUserRealm(tt.recipient))
// 			wugnot.Approve(cross, poolAddr, maxApprove)
// 			gns.Approve(cross, poolAddr, maxApprove)

// 			// teller := common.GetTokenTeller(wugnotPath)
// 			// teller.Approve(poolAddr, maxApprove)
// 			wugnot.Approve(cross, poolAddr, maxApprove)

// 			// Position Creation
// 			pn.Mint(
// 				tt.tokenPath0,
// 				tt.tokenPath1,
// 				tt.feeTier,
// 				tt.tickLower,
// 				tt.tickUpper,
// 				"10000000",
// 				"10000000",
// 				"0",
// 				"0",
// 				max_timeout,
// 				tt.recipient,
// 				tt.recipient,
// 				"",
// 			)

// 			pool := GetPool(tt.tokenPath0, tt.tokenPath1, tt.feeTier)
// 			posKey := getPositionKey(positionAddr, tt.tickLower, tt.tickUpper)
// 			pool.mustGetPosition(posKey)

// 			testing.SkipHeights(1)

// 			// Swap
// 			testing.SetOriginCaller(tt.recipient)
// 			wugnot.Transfer(cross, routerAddr, 20000000)
// 			gns.Transfer(cross, routerAddr, 20000000)

// 			testing.SetRealm(rouRealm)
// 			wugnot.Approve(cross, poolAddr, maxApprove)

// 			Swap(
// 				cross,
// 				tt.tokenPath0,
// 				tt.tokenPath1,
// 				tt.feeTier,
// 				tt.recipient,
// 				true,
// 				"1000000",
// 				"3945129629379410362911094632",
// 				tt.recipient,
// 			)
// 			testing.SkipHeights(1)

// 			defer func() {
// 				if r := recover(); r != nil {
// 					if tt.expectPanic {
// 						if errMsg, ok := r.(string); ok {
// 							uassert.Equal(t, "not authorized", errMsg)
// 						}
// 					} else {
// 						t.Errorf("expected panic but got none")
// 					}
// 				}
// 			}()

// 			// Collect
// 			pool = GetPool(tt.tokenPath0, tt.tokenPath1, tt.feeTier)
// 			beforePoolBalance0 := pool.BalanceToken0()
// 			beforePoolBalance1 := pool.BalanceToken1()
// 			testing.SetRealm(std.NewUserRealm(tt.recipient))
// 			collectedAmount0, collectedAmount1 := CollectProtocolByAdmin(
// 				cross,
// 				tt.tokenPath0,
// 				tt.tokenPath1,
// 				tt.feeTier,
// 				tt.recipient,
// 				tt.amount0Requested,
// 				tt.amount1Requested,
// 			)
// 			if !tt.expectPanic {
// 				uassert.Equal(t, tt.expectedAmount0, collectedAmount0)
// 				uassert.Equal(t, tt.expectedAmount1, collectedAmount1)

// 				pool = GetPool(tt.tokenPath0, tt.tokenPath1, tt.feeTier)
// 				afterPoolBalance0 := pool.BalanceToken0()
// 				afterPoolBalance1 := pool.BalanceToken1()

// 				uassert.Equal(t, u256.Zero().Sub(beforePoolBalance0, afterPoolBalance0).ToString(), collectedAmount0)
// 				uassert.Equal(t, u256.Zero().Sub(beforePoolBalance1, afterPoolBalance1).ToString(), collectedAmount1)
// 			}
// 		})
// 	}
// }
