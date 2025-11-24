package v1

import (
	"chain"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	ufmt "gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/mock"
)

func TestAssertIsNotExpired(t *testing.T) {
	tests := []struct {
		name                 string
		deadline             int64
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid deadline is future time",
			deadline:    time.Now().Unix() + 3600, // 1 hour from now
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is far future",
			deadline:    time.Now().Unix() + 86400*365, // 1 year from now
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is current time (not expired)",
			deadline:    time.Now().Unix(),
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is max int64 deadline",
			deadline:    9223372036854775807,
			shouldPanic: false,
		},
		{
			name:                 "Expired deadline is past time",
			deadline:             time.Now().Unix() - 1,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), time.Now().Unix()-1),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is far past",
			deadline:             time.Now().Unix() - 86400,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), time.Now().Unix()-86400),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is zero deadline",
			deadline:             0,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), 0),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is negative deadline",
			deadline:             -1,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-007] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), -1),
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsNotExpired(tt.deadline)
				})
			} else {
				assertIsNotExpired(tt.deadline)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertValidLiquidityAmount(t *testing.T) {
	tests := []struct {
		name                 string
		liquidity            string
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid liquidity is positive number",
			liquidity:   "1000000",
			shouldPanic: false,
		},
		{
			name:        "Valid liquidity is large number",
			liquidity:   "999999999999999999999999999999999",
			shouldPanic: false,
		},
		{
			name:        "Valid liquidity is minimum valid (1)",
			liquidity:   "1",
			shouldPanic: false,
		},
		{
			name:                 "Invalid liquidity is zero",
			liquidity:            "0",
			expectedPanicMessage: "[GNOSWAP-POSITION-010] zero liquidity || liquidity amount must be greater than 0, got 0",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is negative (will panic in u256)",
			liquidity:            "-1",
			expectedPanicMessage: "strconv.ParseUint: parsing \"-1\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is non-numeric",
			liquidity:            "abc",
			expectedPanicMessage: "strconv.ParseUint: parsing \"abc\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is empty string",
			liquidity:            "",
			expectedPanicMessage: "EOF",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertValidLiquidityAmount(tt.liquidity)
				})
			} else {
				assertValidLiquidityAmount(tt.liquidity)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertExistsPosition(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		setupPosition        bool
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Position exists",
			positionId:    1,
			setupPosition: true,
			shouldPanic:   false,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Position ID is 0",
			positionId:           0,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(0) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Large position ID doesn't exist",
			positionId:           18446744073709551615,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(18446744073709551615) doesn't exist",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				position := newDummyPosition(tt.positionId)
				mockInstance.createNewPosition(tt.positionId, position)

				mockInstance.nftAccessor.Mint(adminAddr, positionIdFrom(tt.positionId))
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertExistsPosition(mockInstance, tt.positionId)
				})
			} else {
				assertExistsPosition(mockInstance, tt.positionId)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsOwnerForToken(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		caller               address
		setupPosition        bool
		setupOwner           address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Valid owner",
			positionId:    1,
			caller:        adminAddr,
			setupPosition: true,
			setupOwner:    adminAddr,
			shouldPanic:   false,
		},
		{
			name:                 "Not the owner",
			positionId:           1,
			caller:               alice,
			setupPosition:        true,
			setupOwner:           adminAddr,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller(g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) is not owner of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			caller:               adminAddr,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Empty address as caller",
			positionId:           1,
			caller:               "",
			setupPosition:        true,
			setupOwner:           adminAddr,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller() is not owner of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:          "Owner is bob",
			positionId:    2,
			caller:        bob,
			setupPosition: true,
			setupOwner:    bob,
			shouldPanic:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				testing.SetRealm(posRealm)
				mockInstance.nftAccessor.Mint(tt.setupOwner, positionIdFrom(tt.positionId))
				position := newDummyPosition(tt.positionId)
				mockInstance.createNewPosition(tt.positionId, position)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsOwnerForToken(mockInstance, tt.positionId, tt.caller)
				})
			} else {
				assertIsOwnerForToken(mockInstance, tt.positionId, tt.caller)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsOwnerOrOperatorForToken(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		isStaked             bool
		caller               address
		setupPosition        bool
		setupOwner           address
		setupOperator        address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Caller is owner",
			positionId:    1,
			isStaked:      false,
			caller:        adminAddr,
			setupPosition: true,
			setupOwner:    adminAddr,
			shouldPanic:   false,
		},
		{
			name:          "Caller is operator",
			positionId:    1,
			isStaked:      true,
			caller:        alice,
			setupPosition: true,
			setupOwner:    adminAddr,
			setupOperator: alice,
			shouldPanic:   false,
		},
		{
			name:                 "Caller is neither owner nor operator",
			positionId:           1,
			isStaked:             false,
			caller:               bob,
			setupPosition:        true,
			setupOwner:           adminAddr,
			setupOperator:        alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller(g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) is not owner or approved operator of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			isStaked:             false,
			caller:               adminAddr,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-013] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:          "Owner and operator are the same",
			positionId:    2,
			isStaked:      false,
			caller:        alice,
			setupPosition: true,
			setupOwner:    alice,
			setupOperator: alice,
			shouldPanic:   false,
		},
		{
			name:                 "Empty address as caller",
			positionId:           1,
			isStaked:             false,
			caller:               "",
			setupPosition:        true,
			setupOwner:           adminAddr,
			setupOperator:        alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller() is not owner or approved operator of positionId(1)",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				testing.SetRealm(posRealm)
				mockInstance.nftAccessor.Mint(tt.setupOwner, positionIdFrom(tt.positionId))

				position := newDummyPosition(tt.positionId)
				if tt.setupOperator != "" {
					if tt.isStaked {
						stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
						nftAccessor := mockInstance.nftAccessor.(*mock.MockNFTAccessor)
						nftAccessor.SetOwner(positionIdFrom(tt.positionId), stakerAddr)
					}

					position.SetOperator(tt.setupOperator)
				}
				mockInstance.createNewPosition(tt.positionId, position)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsOwnerOrOperatorForToken(mockInstance, tt.positionId, tt.caller)
				})
			} else {
				assertIsOwnerOrOperatorForToken(mockInstance, tt.positionId, tt.caller)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertEqualsAddress(t *testing.T) {
	tests := []struct {
		name                 string
		prevAddr             address
		otherAddr            address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid equal addresses",
			prevAddr:    adminAddr,
			otherAddr:   adminAddr,
			shouldPanic: false,
		},
		{
			name:        "Valid equal addresses - alice",
			prevAddr:    alice,
			otherAddr:   alice,
			shouldPanic: false,
		},
		{
			name:                 "Different addresses",
			prevAddr:             adminAddr,
			otherAddr:            alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] invalid address || (g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d, g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh)",
			shouldPanic:          true,
		},
		{
			name:                 "First address is invalid (empty)",
			prevAddr:             "",
			otherAddr:            alice,
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Second address is invalid (empty)",
			prevAddr:             alice,
			otherAddr:            "",
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Both addresses are invalid (empty)",
			prevAddr:             "",
			otherAddr:            "",
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Different valid addresses",
			prevAddr:             bob,
			otherAddr:            "g1charlie",
			expectedPanicMessage: "invalid address: g1charlie",
			shouldPanic:          true,
		},
		{
			name:                 "Same address with different case (should be equal)",
			prevAddr:             "g1alice",
			otherAddr:            "g1alice",
			expectedPanicMessage: "invalid address: g1alice",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertEqualsAddress(tt.prevAddr, tt.otherAddr)
				})
			} else {
				assertEqualsAddress(tt.prevAddr, tt.otherAddr)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertSlippageIsNotExceeded(t *testing.T) {
	tests := []struct {
		name                 string
		amount0              *u256.Uint
		amount1              *u256.Uint
		amount0Min           *u256.Uint
		amount1Min           *u256.Uint
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "No slippage - exact amounts",
			amount0:     u256.NewUint(1000),
			amount1:     u256.NewUint(2000),
			amount0Min:  u256.NewUint(1000),
			amount1Min:  u256.NewUint(2000),
			shouldPanic: false,
		},
		{
			name:        "Acceptable slippage - amounts greater than minimum",
			amount0:     u256.NewUint(1100),
			amount1:     u256.NewUint(2200),
			amount0Min:  u256.NewUint(1000),
			amount1Min:  u256.NewUint(2000),
			shouldPanic: false,
		},
		{
			name:                 "Slippage exceeded on amount0",
			amount0:              u256.NewUint(900),
			amount1:              u256.NewUint(2000),
			amount0Min:           u256.NewUint(1000),
			amount1Min:           u256.NewUint(2000),
			expectedPanicMessage: "[GNOSWAP-POSITION-002] slippage failed || amount0(900) >= amount0Min(1000) && amount1(2000) >= amount1Min(2000)",
			shouldPanic:          true,
		},
		{
			name:                 "Slippage exceeded on amount1",
			amount0:              u256.NewUint(1000),
			amount1:              u256.NewUint(1900),
			amount0Min:           u256.NewUint(1000),
			amount1Min:           u256.NewUint(2000),
			expectedPanicMessage: "[GNOSWAP-POSITION-002] slippage failed || amount0(1000) >= amount0Min(1000) && amount1(1900) >= amount1Min(2000)",
			shouldPanic:          true,
		},
		{
			name:                 "Slippage exceeded on both amounts",
			amount0:              u256.NewUint(900),
			amount1:              u256.NewUint(1900),
			amount0Min:           u256.NewUint(1000),
			amount1Min:           u256.NewUint(2000),
			expectedPanicMessage: "[GNOSWAP-POSITION-002] slippage failed || amount0(900) >= amount0Min(1000) && amount1(1900) >= amount1Min(2000)",
			shouldPanic:          true,
		},
		{
			name:        "Zero minimum amounts",
			amount0:     u256.NewUint(100),
			amount1:     u256.NewUint(200),
			amount0Min:  u256.Zero(),
			amount1Min:  u256.Zero(),
			shouldPanic: false,
		},
		{
			name:                 "Zero actual amounts with non-zero minimums",
			amount0:              u256.Zero(),
			amount1:              u256.Zero(),
			amount0Min:           u256.NewUint(100),
			amount1Min:           u256.NewUint(200),
			expectedPanicMessage: "[GNOSWAP-POSITION-002] slippage failed || amount0(0) >= amount0Min(100) && amount1(0) >= amount1Min(200)",
			shouldPanic:          true,
		},
		{
			name:        "Large numbers",
			amount0:     u256.MustFromDecimal("1000000000000000000000"),
			amount1:     u256.MustFromDecimal("2000000000000000000000"),
			amount0Min:  u256.MustFromDecimal("999999999999999999999"),
			amount1Min:  u256.MustFromDecimal("1999999999999999999999"),
			shouldPanic: false,
		},
		{
			name:        "Valid input - amount0 exactly at minimum, amount1 above",
			amount0:     u256.NewUint(1000),
			amount1:     u256.NewUint(2001),
			amount0Min:  u256.NewUint(1000),
			amount1Min:  u256.NewUint(2000),
			shouldPanic: false,
		},
		{
			name:                 "Invalid input - amount0 above minimum, amount1 just below",
			amount0:              u256.NewUint(1001),
			amount1:              u256.NewUint(1999),
			amount0Min:           u256.NewUint(1000),
			amount1Min:           u256.NewUint(2000),
			expectedPanicMessage: "[GNOSWAP-POSITION-002] slippage failed || amount0(1001) >= amount0Min(1000) && amount1(1999) >= amount1Min(2000)",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertSlippageIsNotExceeded(tt.amount0, tt.amount1, tt.amount0Min, tt.amount1Min)
				})
			} else {
				assertSlippageIsNotExceeded(tt.amount0, tt.amount1, tt.amount0Min, tt.amount1Min)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsValidUserCoinSendWithTokenPair(t *testing.T) {
	tests := []struct {
		name                 string
		token0               string
		token1               string
		amount0              string
		amount1              string
		sentCoins            chain.Coins
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "GNOT native path in token0",
			token0:      common.GNOT_PATH,
			token1:      gnsPath,
			amount0:     "1000",
			amount1:     "2000",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			shouldPanic: false,
		},
		{
			name:        "GNOT native path in token1",
			token0:      gnsPath,
			token1:      common.GNOT_PATH,
			amount0:     "2000",
			amount1:     "1000",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			shouldPanic: false,
		},
		{
			name:                 "GNOT native path with wrong amount",
			token0:               common.GNOT_PATH,
			token1:               gnsPath,
			amount0:              "1000",
			amount1:              "2000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 500}},
			expectedPanicMessage: "[GNOSWAP-COMMON-012] user send ugnot amount is not equal to specified amount",
			shouldPanic:          true,
		},
		{
			name:        "No native tokens",
			token0:      gnsPath,
			token1:      barPath,
			amount0:     "1000",
			amount1:     "2000",
			sentCoins:   chain.Coins{},
			shouldPanic: false,
		},
		{
			name:                 "No native tokens but coins sent",
			token0:               gnsPath,
			token1:               barPath,
			amount0:              "1000",
			amount1:              "2000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 100}},
			expectedPanicMessage: "[GNOSWAP-COMMON-013] handle native coin is not allowed",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid amount0 (non-numeric)",
			token0:               common.GNOT_PATH,
			token1:               gnsPath,
			amount0:              "abc",
			amount1:              "2000",
			sentCoins:            chain.Coins{},
			expectedPanicMessage: "strconv.ParseInt: parsing \"abc\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid amount1 (non-numeric)",
			token0:               gnsPath,
			token1:               common.GNOT_PATH,
			amount0:              "1000",
			amount1:              "xyz",
			sentCoins:            chain.Coins{},
			expectedPanicMessage: "strconv.ParseInt: parsing \"xyz\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:        "Large valid amounts",
			token0:      common.GNOT_PATH,
			token1:      gnsPath,
			amount0:     "999999999999",
			amount1:     "888888888888",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 999999999999}},
			shouldPanic: false,
		},
		{
			name:        "Zero amount for GNOT",
			token0:      common.GNOT_PATH,
			token1:      gnsPath,
			amount0:     "0",
			amount1:     "1000",
			sentCoins:   chain.Coins{},
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetOriginSend(chain.Coins{})

			// Setup sent coins context
			if len(tt.sentCoins) > 0 {
				// Simulate user sent coins by setting the proper realm
				userAddr := address("g1user")
				testing.SetRealm(testing.NewUserRealm(userAddr))
				testing.SetOriginSend(tt.sentCoins)
			} else {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsValidUserCoinSendWithTokenPair(tt.token0, tt.token1, tt.amount0, tt.amount1)
				})
			} else {
				assertIsValidUserCoinSendWithTokenPair(tt.token0, tt.token1, tt.amount0, tt.amount1)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsValidUserCoinSendWithWrappedTokenPair(t *testing.T) {
	tests := []struct {
		name                 string
		token0               string
		token1               string
		amount0              string
		amount1              string
		sentCoins            chain.Coins
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "WUGNOT path in token0 with coins",
			token0:      wugnotPath,
			token1:      gnsPath,
			amount0:     "1000",
			amount1:     "2000",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			shouldPanic: false,
		},
		{
			name:        "WUGNOT path in token1 with coins",
			token0:      gnsPath,
			token1:      wugnotPath,
			amount0:     "2000",
			amount1:     "1000",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			shouldPanic: false,
		},
		{
			name:        "WUGNOT path without coins (pre-wrapped)",
			token0:      wugnotPath,
			token1:      gnsPath,
			amount0:     "1000",
			amount1:     "2000",
			sentCoins:   chain.Coins{},
			shouldPanic: false,
		},
		{
			name:                 "WUGNOT path with wrong amount",
			token0:               wugnotPath,
			token1:               gnsPath,
			amount0:              "1000",
			amount1:              "2000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 500}},
			expectedPanicMessage: "[GNOSWAP-COMMON-012] user send ugnot amount is not equal to specified amount",
			shouldPanic:          true,
		},
		{
			name:        "No wrapped tokens, no coins",
			token0:      gnsPath,
			token1:      barPath,
			amount0:     "1000",
			amount1:     "2000",
			sentCoins:   chain.Coins{},
			shouldPanic: false,
		},
		{
			name:                 "No wrapped tokens but coins sent",
			token0:               gnsPath,
			token1:               barPath,
			amount0:              "1000",
			amount1:              "2000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 100}},
			expectedPanicMessage: "[GNOSWAP-COMMON-013] handle native coin is not allowed",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid amount0 for wrapped token",
			token0:               wugnotPath,
			token1:               gnsPath,
			amount0:              "invalid",
			amount1:              "1000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			expectedPanicMessage: "strconv.ParseInt: parsing \"invalid\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid amount1 for wrapped token",
			token0:               gnsPath,
			token1:               wugnotPath,
			amount0:              "1000",
			amount1:              "notanumber",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			expectedPanicMessage: "strconv.ParseInt: parsing \"notanumber\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:        "Large amounts with wrapped tokens",
			token0:      wugnotPath,
			token1:      gnsPath,
			amount0:     "999999999999",
			amount1:     "888888888888",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 999999999999}},
			shouldPanic: false,
		},
		{
			name:                 "Zero amount for wrapped token with coins",
			token0:               wugnotPath,
			token1:               gnsPath,
			amount0:              "0",
			amount1:              "1000",
			sentCoins:            chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 100}},
			expectedPanicMessage: "[GNOSWAP-COMMON-012] user send ugnot amount is not equal to specified amount",
			shouldPanic:          true,
		},
		{
			name:      "Zero send amount for wrapped token with coins",
			token0:    wugnotPath,
			token1:    gnsPath,
			amount0:   "0",
			amount1:   "1000",
			sentCoins: chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 0}},
		},
		{
			name:        "Both tokens are wrapped tokens (edge case)",
			token0:      wugnotPath,
			token1:      wugnotPath,
			amount0:     "1000",
			amount1:     "1000",
			sentCoins:   chain.Coins{chain.Coin{Denom: ugnotDenom, Amount: 1000}},
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetOriginSend(chain.Coins{})

			// Setup sent coins context
			if len(tt.sentCoins) > 0 {
				// Simulate user sent coins by setting the proper realm
				userAddr := address("g1user")
				testing.SetRealm(testing.NewUserRealm(userAddr))
				testing.SetOriginSend(tt.sentCoins)
			} else {
				testing.SetRealm(testing.NewUserRealm(adminAddr))
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsValidUserCoinSendWithWrappedTokenPair(tt.token0, tt.token1, tt.amount0, tt.amount1)
				})
			} else {
				assertIsValidUserCoinSendWithWrappedTokenPair(tt.token0, tt.token1, tt.amount0, tt.amount1)
				uassert.Equal(t, true, true)
			}
		})
	}
}
