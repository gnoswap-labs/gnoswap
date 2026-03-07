package v1

import (
	"strconv"
	"testing"
	"time"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

func TestMintAndStake(t *testing.T) {
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
		// --- basic success ---
		{
			name:           "success - bar/foo, fee 100, full range",
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
			name:           "success - foo/bar (token order swapped)",
			token0:         fooPath,
			token1:         barPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "200000000",
			amount1Desired: "100000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "success - gns/foo pair",
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
			name:           "success - small amounts",
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
		// --- fee tiers ---
		{
			name:           "success - fee tier 500 (0.05%)",
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
			name:             "fail - fee tier 500, invalid tick range",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(500),
			tickLower:        -887221,
			tickUpper:        887221,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "0",
			amount1Min:       "0",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-017] invalid tick and tick spacing requested",
		},
		{
			name:           "success - fee tier 10000 (1%)",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(10000),
			tickLower:      -880000,
			tickUpper:      880000,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "0",
			amount1Min:     "0",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:             "fail - fee tier 10000, invalid tick range",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(10000),
			tickLower:        -887222,
			tickUpper:        887222,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "0",
			amount1Min:       "0",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POOL-017] invalid tick and tick spacing requested",
		},
		// --- tick validation ---
		{
			name:             "fail - tick lower equals tick upper",
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
			expectedPanicMsg: "[GNOSWAP-COMMON-005] identical ticks",
		},
		{
			name:             "fail - tick lower greater than tick upper",
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
			expectedPanicMsg: "[GNOSWAP-POOL-018] tickLower is greater than or equal to tickUpper",
		},
		// --- slippage / min amounts ---
		{
			name:             "fail - min amounts exceed actual (slippage)",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "100000000",
			amount1Desired:   "200000000",
			amount0Min:       "90000000",
			amount1Min:       "120000000",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "[GNOSWAP-POSITION-002] slippage failed",
		},
		{
			name:           "success - desired amounts equal to minimums",
			token0:         barPath,
			token1:         fooPath,
			fee:            uint32(100),
			tickLower:      -887220,
			tickUpper:      887220,
			amount0Desired: "100000000",
			amount1Desired: "200000000",
			amount0Min:     "100000000",
			amount1Min:     "100000000",
			deadline:       time.Now().Unix() + 10000000,
			referrer:       "",
			expectPanic:    false,
		},
		{
			name:           "success - desired amounts greater than minimums",
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
			name:             "fail - desired amounts less than minimums",
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
		// --- balance ---
		{
			name:             "fail - insufficient balance",
			token0:           barPath,
			token1:           fooPath,
			fee:              uint32(100),
			tickLower:        -887220,
			tickUpper:        887220,
			amount0Desired:   "999999999999999999",
			amount1Desired:   "999999999999999999",
			amount0Min:       "0",
			amount1Min:       "0",
			deadline:         time.Now().Unix() + 10000000,
			referrer:         "",
			expectPanic:      true,
			expectedPanicMsg: "insufficient balance",
		},
		// --- referrer ---
		{
			name:           "success - with valid referrer",
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross, 0)

			poolPath := pl.GetPoolPath(tt.token0, tt.token1, tt.fee)
			instance.setPoolTier(poolPath, 1, time.Now().Unix())

			CreatePool(tt.token0, tt.token1, tt.fee, "79228162514264337593543950336", adminAddr)

			amount0DesiredInt64, _ := strconv.ParseInt(tt.amount0Desired, 10, 64)
			amount1DesiredInt64, _ := strconv.ParseInt(tt.amount1Desired, 10, 64)

			common.SafeGRC20Approve(cross, tt.token0, poolAddr, amount0DesiredInt64)
			common.SafeGRC20Approve(cross, tt.token1, poolAddr, amount1DesiredInt64)

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
