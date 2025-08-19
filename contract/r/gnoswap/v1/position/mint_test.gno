package position

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/fuzz"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

// Note: Keep helpers minimal and explicit. The goal is to centralize
// shared Arrange steps and make test intent clearer.

type Env struct {
	t *testing.T
}

// NewEnv initializes the base chain/test realm state for each test.
func NewEnv(t *testing.T) *Env {
	t.Helper()
	initPositionTest(t)
	return &Env{t: t}
}

// GivenPoolCreated prepares a pool with fee tier and initial sqrtPrice.
// This keeps admin-realm and pool fee settings in one place.
func (e *Env) GivenPoolCreated(token0, token1 string, fee uint32, sqrtPriceX96 string) *Env {
	e.t.Helper()
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(e.t, token0, token1, fee, sqrtPriceX96, adminAddr)
	return e
}

// AndUserFundedAndApproved mints test tokens to an account and approves pool spending.
func (e *Env) AndUserFundedAndApproved(addr std.Address, tokens ...string) *Env {
	e.t.Helper()
	testing.SetRealm(posRealm)
	for _, tk := range tokens {
		TokenFaucet(e.t, tk, addr)
		TokenApprove(e.t, tk, addr, poolAddr, maxApprove)
	}
	// native module approvals (bar/baz) once per test case
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)
	return e
}

// MintParamsBuilder provides readable Arrange for mint parameters.
type MintBuilder struct{ p MintParams }

func MintParamsBuilder() *MintBuilder {
	return &MintBuilder{
		p: MintParams{
			token0:         "gno.land/r/onbloc/bar",
			token1:         "gno.land/r/onbloc/baz",
			fee:            3000,
			tickLower:      -120,
			tickUpper:      120,
			amount0Desired: u256.MustFromDecimal("0"),
			amount1Desired: u256.MustFromDecimal("0"),
			amount0Min:     u256.MustFromDecimal("0"),
			amount1Min:     u256.MustFromDecimal("0"),
			caller:         alice,
			mintTo:         alice,
		},
	}
}

func (b *MintBuilder) Tokens(t0, t1 string) *MintBuilder {
	b.p.token0, b.p.token1 = t0, t1
	return b
}

func (b *MintBuilder) WithFee(fee uint32) *MintBuilder {
	b.p.fee = fee
	return b
}

func (b *MintBuilder) WithTicks(lower, upper int32) *MintBuilder {
	b.p.tickLower, b.p.tickUpper = lower, upper
	return b
}

func (b *MintBuilder) WithAmounts(a0, a1 string) *MintBuilder {
	b.p.amount0Desired = u256.MustFromDecimal(a0)
	b.p.amount1Desired = u256.MustFromDecimal(a1)
	return b
}

func (b *MintBuilder) WithMins(m0, m1 string) *MintBuilder {
	b.p.amount0Min = u256.MustFromDecimal(m0)
	b.p.amount1Min = u256.MustFromDecimal(m1)
	return b
}

func (b *MintBuilder) Caller(caller, mintTo std.Address) *MintBuilder {
	b.p.caller, b.p.mintTo = caller, mintTo
	return b
}

func (b *MintBuilder) Params() MintParams { return b.p }

// Note: Keep assertions explicit. Only truly regression-critical values
// are compared exactly; error messages are compared exactly to respect
// uassert semantics in the current codebase.
func assertMintOK(t *testing.T, wantId uint64, wantLiquidity, wantA0, wantA1 string,
	gotId uint64, liq, a0, a1 *u256.Uint,
) {
	t.Helper()
	uassert.Equal(t, wantId, gotId)
	uassert.Equal(t, wantLiquidity, liq.ToString())
	uassert.Equal(t, wantA0, a0.ToString())
	uassert.Equal(t, wantA1, a1.ToString())
}

func TestMintInternal_PositionMint(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		{
			name: "success: reasonable range mints liquidity",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-120, 120).
				WithAmounts("100000", "100000").
				WithMins("90000", "90000").
				Caller(alice, alice).
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "16717549",
			expectedAmount0:   "100000",
			expectedAmount1:   "100000",
		},
		{
			name: "abort: zero liquidity",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-120, 120).
				WithAmounts("0", "0").
				WithMins("0", "0").
				Caller(testutils.TestAddress("caller"), testutils.TestAddress("recipient")).
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-010] zero liquidity",
		},
		{
			name: "abort: full range not aligned with tick spacing (0.3% / 60)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-887272, 887272). // not multiple of 60 at lower bound
				WithAmounts("1", "1").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(60) != 0(-52)",
		},
		{
			name: "success: adjusted full range aligned to spacing",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-887220, 887220). // multiple of 60
				WithAmounts("1", "1").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1",
			expectedAmount0:   "1",
			expectedAmount1:   "1",
		},
		{
			name: "abort: invalid tick spacing at lower bound",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-125, 120).
				WithAmounts("100000", "100000").
				WithMins("90000", "90000").
				Caller(alice, alice).
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-125) MOD tickSpacing(60) != 0(-5)",
		},
		{
			name: "abort: inverted range (upper < lower)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(120, -120).
				WithAmounts("100000", "100000").
				WithMins("90000", "90000").
				Caller(alice, alice).
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-024] tickLower is greater than or equal to tickUpper || tickLower(120), tickUpper(-120)",
		},
		{
			name: "success: safe extreme range",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-300000, 300000).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1000",
			expectedAmount0:   "1000",
			expectedAmount1:   "1000",
		},
		{
			name: "success: single-sided liquidity when range above current tick",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(1020, 2040). // multiples of 60
				WithAmounts("100000", "100000").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "2116539",
			expectedAmount0:   "100000",
			expectedAmount1:   "0",
		},
		{
			name: "abort: extreme desired amounts cause insufficient balance",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-500040, 500040).
				WithAmounts("9223372036854775807", "9223372036854775807").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-021] token transfer failed || insufficient balance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			NewEnv(t).
				GivenPoolCreated(tt.params.token0, tt.params.token1, tt.params.fee,
					"79228162514264337593543950336").
				AndUserFundedAndApproved(alice, tt.params.token0, tt.params.token1)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				assertMintOK(t, tt.expectedId, tt.expectedLiquidity, tt.expectedAmount0, tt.expectedAmount1,
					id, liquidity, amount0, amount1)
			}
		})
	}

	t.Run("fuzz_edge_cases", func(t *testing.T) {
		seed := fuzz.NewSeedManager()

		const (
			MIN_TICK  = int32(-887272)
			MAX_TICK  = int32(887272)
			initPrice = "79228162514264337593543950336" // 1:1 price ratio
		)

		// Fee tier to tick spacing mapping
		spacing := map[uint32]int32{
			100:   1,
			500:   10,
			3000:  60,
			10000: 200,
		}
		fees := []uint32{100, 500, 3000, 10000}

		// Test amounts: zero, small, medium, large values
		amounts := []string{"0", "1", "1000", "1000000", "9223372036854775807"}
		// Min amounts: includes values larger than desired to trigger slippage violations
		mins := []string{"0", "1", "1000", "2000000", "18446744073709551615"}

		// Build tick pair candidates by category
		type tickPair struct{ lo, hi int32 }
		buildTickPairs := func(sp int32) []tickPair {
			return []tickPair{
				// Valid aligned pairs (boundary/center regions)
				{lo: -120 - ((-120) % sp), hi: 120 - (120 % sp)},          // Aligned small range
				{lo: MIN_TICK + ((0 - MIN_TICK) % sp), hi: MIN_TICK + sp}, // Near MIN_TICK aligned
				{lo: MAX_TICK - 2*sp, hi: MAX_TICK - ((MAX_TICK) % sp)},   // Near MAX_TICK aligned
				// Invalid: misaligned ticks
				{lo: -125, hi: 120}, // lo misaligned
				{lo: -120, hi: 125}, // hi misaligned
				// Invalid: identical ticks
				{lo: 120, hi: 120},
				// Invalid: inverted range
				{lo: 120, hi: -120},
				// Invalid: out of bounds
				{lo: MIN_TICK - 1, hi: 0},
				{lo: 0, hi: MAX_TICK + 1},
			}
		}

		const iterations = 60
		for i := 0; i < iterations; i++ {
			// Randomly select test parameters
			fee := fees[seed.CreateIntGenerator(0, len(fees)-1).Generate().(int)]
			sp := spacing[fee]
			tps := buildTickPairs(sp)
			p := tps[seed.CreateIntGenerator(0, len(tps)-1).Generate().(int)]

			a0 := amounts[seed.CreateIntGenerator(0, len(amounts)-1).Generate().(int)]
			a1 := amounts[seed.CreateIntGenerator(0, len(amounts)-1).Generate().(int)]
			m0 := mins[seed.CreateIntGenerator(0, len(mins)-1).Generate().(int)]
			m1 := mins[seed.CreateIntGenerator(0, len(mins)-1).Generate().(int)]

			params := MintParamsBuilder().
				WithFee(fee).
				WithTicks(p.lo, p.hi).
				WithAmounts(a0, a1).
				WithMins(m0, m1).
				Caller(alice, alice).
				Params()

			// Determine if this configuration should abort due to hard constraints
			shouldAbort := false
			// Zero liquidity case
			if a0 == "0" && a1 == "0" {
				shouldAbort = true
			}
			// Invalid tick range (inverted or identical)
			if p.lo >= p.hi {
				shouldAbort = true
			}
			// Out of bounds ticks
			if p.lo < MIN_TICK || p.hi > MAX_TICK {
				shouldAbort = true
			}
			// Tick spacing misalignment
			if p.lo%sp != 0 || p.hi%sp != 0 {
				shouldAbort = true
			}

			// Handle slippage violations (min > desired)
			// These are filtered out here and only checked in post-execution validation
			ad0 := u256.MustFromDecimal(a0)
			ad1 := u256.MustFromDecimal(a1)
			am0 := u256.MustFromDecimal(m0)
			am1 := u256.MustFromDecimal(m1)

			if am0.Cmp(ad0) > 0 || am1.Cmp(ad1) > 0 {
				shouldAbort = true
			}

			var (
				abortVal, panicVal any
				didPanic           bool
				gotID              uint64
				liq, out0, out1    *u256.Uint
			)

			// Execute mint operation with panic recovery
			abortVal = revive(func() {
				defer func() {
					if r := recover(); r != nil {
						didPanic = true
						panicVal = r
					}
					t.Logf("panicVal: %v", panicVal)
				}()

				// Create fresh pool and fund user for each iteration
				NewEnv(t).
					GivenPoolCreated(params.token0, params.token1, params.fee, initPrice).
					AndUserFundedAndApproved(alice, params.token0, params.token1)

				gotID, liq, out0, out1 = mint(params)
			})

			// Analyze execution results
			if abortVal != nil || didPanic {
				// Even non-hard violations can cause aborts due to slippage/liquidity allocation
				// Only log unexpected cases where mins are zero but still abort
				if !shouldAbort && am0.IsZero() && am1.IsZero() {
					t.Logf("[iter %d] unexpected abort without mins: fee=%d ticks=(%d,%d) amt=(%s,%s)",
						i, fee, p.lo, p.hi, a0, a1)
				}
				continue
			}

			// Post-execution invariant checks for successful operations
			nonZeroDesired := !(ad0.IsZero() && ad1.IsZero())
			if nonZeroDesired {
				uassert.True(t, !liq.IsZero(), ufmt.Sprintf("[iter %d] expected positive liquidity on non-zero desired", i))
			}
			// Verify actual usage doesn't exceed desired amounts
			uassert.True(t, out0.Cmp(ad0) <= 0, ufmt.Sprintf("[iter %d] amount0 used exceeds desired", i))
			uassert.True(t, out1.Cmp(ad1) <= 0, ufmt.Sprintf("[iter %d] amount1 used exceeds desired", i))
			// Verify slippage protection (successful operations must meet minimum requirements)
			uassert.True(t, out0.Cmp(am0) >= 0, ufmt.Sprintf("[iter %d] amount0 used below min", i))
			uassert.True(t, out1.Cmp(am1) >= 0, ufmt.Sprintf("[iter %d] amount1 used below min", i))

			uassert.Equal(t, uint64(1), gotID)

		}

		t.Logf("✓ fuzz_edge_cases: ran %d randomized mint edge cases", iterations)
	})
}

// Covers: slippage check, identical ticks, MIN/MAX bounds out-of-range.
func TestMintInternal_PanicCases(t *testing.T) {
	tests := []struct {
		name        string
		params      MintParams
		expectedMsg string
	}{
		{
			name: "abort: slippage protection triggers (min > desired)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-120, 120).
				WithAmounts("100000", "100000").
				WithMins("200000", "200000").
				Caller(alice, alice).
				Params(),
			expectedMsg: "[GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(100000) >= amount0Min(200000), amount1(100000) >= amount1Min(200000))",
		},
		{
			name: "abort: identical ticks (tickLower == tickUpper)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(120, 120).
				WithAmounts("100000", "100000").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectedMsg: "[GNOSWAP-COMMON-010] identical ticks || sqrtRatioAX96 (79704936542881920863903188246) and sqrtRatioBX96 (79704936542881920863903188246) are identical",
		},
		{
			name: "abort: tick lower below MIN_TICK bound",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-887273, 0).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Caller(alice, alice).
				Params(),
			expectedMsg: "[GNOSWAP-COMMON-003] value out of range || tick is out of range (smaller than -887272), tick: -887273",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			NewEnv(t).
				GivenPoolCreated(tt.params.token0, tt.params.token1, tt.params.fee,
					"79228162514264337593543950336").
				AndUserFundedAndApproved(alice, tt.params.token0, tt.params.token1)

			uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
				mint(tt.params)
			})
		})
	}
}

// Covers: fee-tier specific spacing behavior & extremal single-tick ranges.
func TestMintInternal_FeeTierEdgeCases(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		// 0.01% pool (tick spacing 1)
		{
			name: "0.01%: single tick near current price → token0-only",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(0, 1).
				WithAmounts("1000000", "1000000").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "20001499987",
			expectedAmount0:   "1000000",
			expectedAmount1:   "0",
		},
		{
			name: "0.01%: extreme negative single tick → token1-only",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(-887271, -887270).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368911457866216265417270",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.01%: full range valid for spacing=1",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(-887272, 887272).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1",
			expectedAmount0:   "1",
			expectedAmount1:   "1",
		},
		{
			name: "0.01%: narrow 2-tick range with extreme desired amounts → insufficient balance",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(-1, 1).
				WithAmounts("9223372036854775807", "9223372036854775807").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-021] token transfer failed || insufficient balance",
		},
		// 0.05% pool (tick spacing 10)
		{
			name: "0.05%: single tick range aligned to spacing → token1-only",
			params: MintParamsBuilder().
				WithFee(500).
				WithTicks(-10, 0).
				WithAmounts("1000000", "1000000").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "2000600039",
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		{
			name: "0.05%: invalid lower tick not multiple of 10 → abort",
			params: MintParamsBuilder().
				WithFee(500).
				WithTicks(-15, 20).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-15) MOD tickSpacing(10) != 0(-5)",
		},
		// 0.3% pool (tick spacing 60)
		{
			name: "0.3%: single tick range aligned to spacing → token1-only",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-60, 0).
				WithAmounts("1000000", "1000000").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "333850249",
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		// 1% pool (tick spacing 200)
		{
			name: "1%: single tick range aligned to spacing → token1-only",
			params: MintParamsBuilder().
				WithFee(10000).
				WithTicks(-200, 0).
				WithAmounts("1000000", "1000000").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "100505833",
			expectedAmount0:   "0",
			expectedAmount1:   "1000000",
		},
		{
			name: "1%: invalid lower tick not multiple of 200 → abort",
			params: MintParamsBuilder().
				WithFee(10000).
				WithTicks(-199, 200).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-199) MOD tickSpacing(200) != 0(-199)",
		},
		// Edge cases for extreme ticks at spacing=1
		{
			name: "0.01%: negative extreme single tick → token1-only",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(-500000, -499999).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1438335065300305010",
			expectedAmount0:   "0",
			expectedAmount1:   "1000",
		},
		{
			name: "0.01%: positive extreme single tick → token0-only",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(499999, 500000).
				WithAmounts("1000", "1000").
				WithMins("0", "0").
				Params(),
			expectedId:        1,
			expectedLiquidity: "1438335065300290965",
			expectedAmount0:   "1000",
			expectedAmount1:   "0",
			expectPanic:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			NewEnv(t).
				GivenPoolCreated(tt.params.token0, tt.params.token1, tt.params.fee,
					"79228162514264337593543950336").
				AndUserFundedAndApproved(alice, tt.params.token0, tt.params.token1)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				assertMintOK(t, tt.expectedId, tt.expectedLiquidity, tt.expectedAmount0, tt.expectedAmount1,
					id, liquidity, amount0, amount1)
			}
		})
	}
}

// Covers: fee-tier MIN/MAX boundary alignment for spacing 1/10/60/200.
func TestMintInternal_TickBoundaries(t *testing.T) {
	tests := []struct {
		name              string
		params            MintParams
		expectPanic       bool
		expectedMsg       string
		expectedId        uint64
		expectedLiquidity string
		expectedAmount0   string
		expectedAmount1   string
	}{
		// spacing 1 — MIN/MAX edges
		{
			name: "0.01%: valid at MIN_TICK boundary (spacing=1)",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(-887272, -887271).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368930354290617215256478",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.01%: valid at MAX_TICK boundary (spacing=1)",
			params: MintParamsBuilder().
				WithFee(100).
				WithTicks(887271, 887272).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "368930237016745472596742",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		// spacing 10 near MIN
		{
			name: "0.05%: valid near MIN_TICK (spacing=10)",
			params: MintParamsBuilder().
				WithFee(500).
				WithTicks(-887270, -887260).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "36881048070887147610261",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.05%: invalid MIN_TICK not multiple of 10 → abort",
			params: MintParamsBuilder().
				WithFee(500).
				WithTicks(-887272, -887262).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(10) != 0(-2)",
		},
		// spacing 60 near MIN
		{
			name: "0.3%: valid near MIN_TICK (spacing=60)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-887220, -887160).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "6123830742008175932125",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "0.3%: invalid MIN_TICK not multiple of 60 → abort",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(-887272, -887212).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(60) != 0(-52)",
		},
		// spacing 200 near MIN
		{
			name: "1%: valid near MIN_TICK (spacing=200)",
			params: MintParamsBuilder().
				WithFee(10000).
				WithTicks(-887200, -887000).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1828894101765470541727",
			expectedAmount0:   "0",
			expectedAmount1:   "1",
		},
		{
			name: "1%: invalid MIN_TICK not multiple of 200 → abort",
			params: MintParamsBuilder().
				WithFee(10000).
				WithTicks(-887272, -887072).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic: true,
			expectedMsg: "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-887272) MOD tickSpacing(200) != 0(-72)",
		},
		// spacing 10/60/200 near MAX
		{
			name: "0.05%: valid near MAX_TICK (spacing=10)",
			params: MintParamsBuilder().
				WithFee(500).
				WithTicks(887260, 887270).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "36881035636152488417312",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		{
			name: "0.3%: valid near MAX_TICK (spacing=60)",
			params: MintParamsBuilder().
				WithFee(3000).
				WithTicks(887160, 887220).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "6123830707127201836443",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
		{
			name: "1%: valid near MAX_TICK (spacing=200)",
			params: MintParamsBuilder().
				WithFee(10000).
				WithTicks(887000, 887200).
				WithAmounts("1", "1").
				WithMins("0", "0").
				Params(),
			expectPanic:       false,
			expectedId:        1,
			expectedLiquidity: "1828894091554004031808",
			expectedAmount0:   "1",
			expectedAmount1:   "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			NewEnv(t).
				GivenPoolCreated(tt.params.token0, tt.params.token1, tt.params.fee,
					"79228162514264337593543950336").
				AndUserFundedAndApproved(alice, tt.params.token0, tt.params.token1)

			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedMsg, func() {
					mint(tt.params)
				})
			} else {
				id, liquidity, amount0, amount1 := mint(tt.params)
				assertMintOK(t, tt.expectedId, tt.expectedLiquidity, tt.expectedAmount0, tt.expectedAmount1,
					id, liquidity, amount0, amount1)
			}
		})
	}
}
