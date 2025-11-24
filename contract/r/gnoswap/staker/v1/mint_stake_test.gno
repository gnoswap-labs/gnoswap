package v1

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

// Test MintAndStake with GNOT
func TestMintAndStakeWithGNOT(t *testing.T) {
	tests := []struct {
		name             string
		token0           string
		token1           string
		fee              uint32
		tickLower        int32
		tickUpper        int32
		amount0Desired   string
		amount1Desired   string
		amount0Min       string
		amount1Min       string
		ugnotSent        int64
		deadline         int64
		referrer         string
		expectPanic      bool
		expectedPanicMsg string
	}{
		{
			name:           "mint and stake with GNOT as token0 - sufficient amount",
			token0:         GNOT,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "mint and stake with GNOT as token1 - sufficient amount",
			token0:         fooPath,
			token1:         GNOT,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "200000000",
			amount1Desired: "100000000",
			amount0Min:     "0",
			amount1Min:     "0",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:             "mint and stake with GNOT - insufficient amount",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "100000000",
			amount1Desired:   "100000000",
			amount0Min:       "0",
			amount1Min:       "0",
			ugnotSent:        100000000 - 1,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-012] user send gnot amount is not equal to specified amount",
		},
		{
			name:             "mint and stake with GNOT - zero amount",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "0",
			amount1Desired:   "100000000",
			amount0Min:       "0",
			amount1Min:       "0",
			ugnotSent:        0,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "too less ugnot sent",
		},
		{
			name:           "mint and stake with valid referrer",
			token0:         GNOT,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "g1valid",
			expectPanic:    false,
		},
		{
			name:           "mint and stake with fee tier 100",
			token0:         GNOT,
			token1:         fooPath,
			fee:            fee100,
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "mint and stake with fee tier 500",
			token0:         GNOT,
			token1:         fooPath,
			fee:            uint32(500),
			tickLower:      -887200,
			tickUpper:      887200,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:             "mint and stake with fee tier 500 with invalid tick range",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(500),
			tickLower:        -887221,
			tickUpper:        887221,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "0",
			amount1Min:       "0",
			ugnotSent:        100000000,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested",
		},
		{
			name:             "mint and stake with fee tier 10000",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(10000),
			tickLower:        -880000,
			tickUpper:        880000,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "0",
			amount1Min:       "0",
			ugnotSent:        100000000,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      false,
			expectedPanicMsg: "",
		},
		{
			name:             "mint and stake with fee tier 10000 with invalid tick range",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(10000),
			tickLower:        -887222,
			tickUpper:        887222,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "0",
			amount1Min:       "0",
			ugnotSent:        100000000,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested",
		},
		{
			name:             "mint and stake with invalid minimum amounts",
			token0:           GNOT,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "90000000",
			amount1Min:       "120000000", // invalid minimum amount
			ugnotSent:        100000000,
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POSITION-002] slippage failed",
		},
		{
			name:           "mint and stake with desired amounts equal to minimums",
			token0:         GNOT,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "100000000",
			amount1Min:     "100000000",
			ugnotSent:      100000000,
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			testing.SetRealm(adminRealm)

			pl.SetPoolCreationFee(cross, 0)

			token0Path := tt.token0
			token1Path := tt.token1

			if token0Path == GNOT {
				token0Path = wugnotPath
			}
			if token1Path == GNOT {
				token1Path = wugnotPath
			}

			poolPath := pl.GetPoolPath(token0Path, token1Path, tt.fee)
			instance.setPoolTier(poolPath, 1, time.Now().Unix())

			CreatePool(token0Path, token1Path, tt.fee, "79228162514264337593543950336", adminAddr)

			amount0DesiredInt64, _ := strconv.ParseInt(tt.amount0Desired, 10, 64)
			amount1DesiredInt64, _ := strconv.ParseInt(tt.amount1Desired, 10, 64)

			common.SafeGRC20Approve(cross, token0Path, poolAddr, amount0DesiredInt64)
			common.SafeGRC20Approve(cross, token1Path, poolAddr, amount1DesiredInt64)

			// Set deadline:time.Now().Unix() + 100000000
			deadline := tt.deadline
			if deadline == 0 {
				deadline = time.Now().Unix() + 1000000
			}

			mintAndStakeFn := func(cur realm) (uint64, string, string, string, string) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
				return instance.MintAndStake(
					tt.token0,
					tt.token1,
					tt.fee,
					tt.tickLower,
					tt.tickUpper,
					tt.amount0Desired,
					tt.amount1Desired,
					tt.amount0Min,
					tt.amount1Min,
					deadline,
					tt.referrer,
				)
			}

			testing.SetOriginSend(chain.Coins{})

			if tt.ugnotSent > 0 {
				sendCoins := chain.Coins{chain.Coin{"ugnot", tt.ugnotSent}}

				testing.SetRealm(adminRealm)
				testing.SetOriginSend(sendCoins)

				testing.IssueCoins(adminAddr, sendCoins)
				banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
				banker_.SendCoins(adminAddr, stakerAddr, sendCoins)
			}

			if tt.expectPanic {
				uassert.AbortsContains(t, tt.expectedPanicMsg, func() {
					mintAndStakeFn(cross)
				})

				staked := instance.IsStaked(1)
				uassert.False(t, staked, "staked should be false")
			} else {
				positionId, _, _, _, _ := mintAndStakeFn(cross)

				staked := instance.IsStaked(positionId)
				uassert.True(t, staked, "staked should be true")
			}
		})
	}
}

// Test MintAndStake without native token
func TestMintAndStakeWithoutNativeToken(t *testing.T) {
	tests := []struct {
		name             string
		token0           string
		token1           string
		fee              uint32
		tickLower        int32
		tickUpper        int32
		amount0Desired   string
		amount1Desired   string
		amount0Min       string
		amount1Min       string
		deadline         int64
		referrer         string
		expectPanic      bool
		expectedPanicMsg string
	}{
		{
			name:           "mint and stake with ERC20 tokens only",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "mint and stake with GNS and FOO",
			token0:         gnsPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "valid tick range",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "1000",
			amount1Desired: "1000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:             "tick lower equals tick upper - invalid",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        100,
			tickUpper:        100,
			amount0Desired:   "1000",
			amount1Desired:   "1000",
			amount0Min:       "0",
			amount1Min:       "0",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-COMMON-010] identical ticks",
		},
		{
			name:             "tick lower greater than tick upper - invalid",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        200,
			tickUpper:        100,
			amount0Desired:   "1000",
			amount1Desired:   "1000",
			amount0Min:       "0",
			amount1Min:       "0",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper",
		},
		{
			name:           "valid referrer address",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "g1valid",
			expectPanic:    false,
		},
		{
			name:           "desired amounts greater than minimums - valid",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "1000",
			amount1Desired: "1000",
			amount0Min:     "900",
			amount1Min:     "900",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:             "desired amounts equal is less than minimums - valid",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "1000",
			amount1Desired:   "1000",
			amount0Min:       "1001",
			amount1Min:       "1001",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POSITION-002] slippage failed",
		},
		{
			name:           "fee tier 100 (0.01%)",
			token0:         barPath,
			token1:         fooPath,
			fee:            fee100,
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "fee tier 500 (0.05%)",
			token0:         barPath,
			token1:         fooPath,
			fee:            fee500,
			tickLower:      -887200,
			tickUpper:      887200,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "fee tier 10000 (1%)",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(10000),
			tickLower:      -887200,
			tickUpper:      887200,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross, 0)

			// Verify no GNOT check is performed for non-GNOT pairs
			hasGNOT := tt.token0 == GNOT || tt.token1 == GNOT
			uassert.False(t, hasGNOT)

			poolPath := pl.GetPoolPath(tt.token0, tt.token1, tt.fee)
			instance.setPoolTier(poolPath, 1, time.Now().Unix())

			CreatePool(tt.token0, tt.token1, tt.fee, "79228162514264337593543950336", adminAddr)

			amount0DesiredInt64, _ := strconv.ParseInt(tt.amount0Desired, 10, 64)
			amount1DesiredInt64, _ := strconv.ParseInt(tt.amount1Desired, 10, 64)

			common.SafeGRC20Approve(cross, tt.token0, poolAddr, amount0DesiredInt64)
			common.SafeGRC20Approve(cross, tt.token1, poolAddr, amount1DesiredInt64)

			// Set deadline:time.Now().Unix() + 100000000
			deadline := tt.deadline
			if deadline == 0 {
				deadline = time.Now().Unix() + 1000000
			}

			mintAndStakeFn := func(cur realm) (uint64, string, string, string, string) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
				return instance.MintAndStake(
					tt.token0,
					tt.token1,
					tt.fee,
					tt.tickLower,
					tt.tickUpper,
					tt.amount0Desired,
					tt.amount1Desired,
					tt.amount0Min,
					tt.amount1Min,
					deadline,
					tt.referrer,
				)
			}

			if tt.expectPanic {
				uassert.AbortsContains(t, tt.expectedPanicMsg, func() {
					mintAndStakeFn(cross)
				})

				staked := instance.IsStaked(1)
				uassert.False(t, staked, "staked should be false")
			} else {
				positionId, _, _, _, _ := mintAndStakeFn(cross)

				staked := instance.IsStaked(positionId)
				uassert.True(t, staked, "staked should be true")
			}
		})
	}
}
