package position

import (
	"math"
	"strconv"
	"strings"
	"testing"
	"time"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	"gno.land/r/gnoswap/staker"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"
	router_v1 "gno.land/r/gnoswap/router/v1"
	staker_v1 "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	FUZZ_ITERATIONS          = 10   // 10 iterations is enough for basic sanity checks
	FUZZ_ITERATIONS_EXTENDED = 1000 // 1000 iterations is enough for extended checks
)

const (
	MIN_SQRT_RATIO = "4295128739"
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"

	MIN_TICK = int32(-887272)
	MAX_TICK = int32(887272)

	// Token paths
	BAR_PATH = "gno.land/r/onbloc/bar"
	FOO_PATH = "gno.land/r/onbloc/foo"
	BAZ_PATH = "gno.land/r/onbloc/baz"

	MAX_TEST_MINT_AMOUNT = math.MaxInt64 / 1000

	// Price limits for swap
	MIN_PRICE_LIMIT_ZERO_FOR_ONE     = "39614081257132168796771975168"  // ~50% of INITIAL_POOL_PRICE
	MAX_PRICE_LIMIT_NOT_ZERO_FOR_ONE = "158456325028528675187087900674" // ~200% of INITIAL_POOL_PRICE
)

var (
	VALID_FEE_TIERS = []uint32{100, 500, 3000, 10000}
	MAX_UINT128     = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 128), u256.One())
)

var (
	adminAddr = access.MustGetAddress(prabc.ROLE_ADMIN.String())

	initializedPool     = false
	initializedPosition = false
	initializedRouter   = false
	initializedStaker   = false
)

var (
	minPriceUint256 = u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxPriceUint256 = u256.MustFromDecimal(MAX_SQRT_RATIO)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"
	oblPath = "gno.land/r/onbloc/obl"

	defaultTokenPaths = map[string]bool{
		barPath: true,
		bazPath: true,
		fooPath: true,
		oblPath: true,
		quxPath: true,
	}

	defaultFeeTiers = []uint32{
		100,
		500,
		3000,
		10000,
	}

	defaultTickSpacings = map[uint32]int32{
		100:   1,
		500:   10,
		3000:  60,
		10000: 200,
	}

	defaultNFTAccessor      = newMockNFTAccessor()
	defaultPoolAccessor     = newMockPoolAccessor()
	defaultEmissionAccessor = newMockEmissionAccessor()

	defaultStakerStore = newMockStakerStore()
)

// initStates initializes the states for the fuzz test
func initStates(t *testing.T) {
	burnTestTokens(t)

	defaultNFTAccessor = newMockNFTAccessor()
	defaultPoolAccessor = newMockPoolAccessor()
	defaultEmissionAccessor = newMockEmissionAccessor()

	initPoolState(t)
	initPositionState(t)
	initRouterState(t)
	initStakerState(t)
}

func initPoolState(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pool.RegisterInitializer(cross, func(_ pool.IPoolStore) pool.IPool {
			return pool_v1.NewPoolV1(newMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.UpgradeImpl(cross, mockPoolPath)
	pool.SetPoolCreationFee(cross, 0)
}

func initPositionState(t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true

		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		position.RegisterInitializer(cross, func(_ position.IPositionStore) position.IPosition {
			return position_v1.NewPositionV1(newMockPositionStore(), defaultNFTAccessor)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	position.UpgradeImpl(cross, mockPositionPath)
}

func initRouterState(t *testing.T) {
	t.Helper()
	const mockRouterPath = "gno.land/r/gnoswap/router/mock"

	if !initializedRouter {
		initializedRouter = true

		testing.SetRealm(testing.NewCodeRealm(mockRouterPath))
		router.RegisterInitializer(cross, func(_ router.IRouterStore) router.IRouter {
			return router_v1.NewRouterV1(newMockRouterStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	router.UpgradeImpl(cross, mockRouterPath)
}

func initStakerState(t *testing.T) {
	t.Helper()
	const mockStakerPath = "gno.land/r/gnoswap/staker/mock"

	defaultStakerStore = newMockStakerStore()

	if !initializedStaker {
		initializedStaker = true

		testing.SetRealm(testing.NewCodeRealm(mockStakerPath))
		staker.RegisterInitializer(cross, func(_ staker.IStakerStore, _ staker.PoolAccessor, _ staker.EmissionAccessor, _ staker.NFTAccessor) staker.IStaker {
			return staker_v1.NewStakerV1(defaultStakerStore, defaultPoolAccessor, defaultEmissionAccessor, defaultNFTAccessor)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.UpgradeImpl(cross, mockStakerPath)
}

func mintTestToken(tokenPath string, amount int64) {
	if amount > MAX_TEST_MINT_AMOUNT {
		panic("mint amount exceeds fuzz test limit")
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	switch tokenPath {
	case barPath:
		bar.Mint(cross, adminAddr, amount)
	case bazPath:
		baz.Mint(cross, adminAddr, amount)
	case fooPath:
		foo.Mint(cross, adminAddr, amount)
	case quxPath:
		qux.Mint(cross, adminAddr, amount)
	case oblPath:
		obl.Mint(cross, adminAddr, amount)
	default:
		return
	}
}

// getTokenTotalSupply returns the total supply of a token
func getTokenTotalSupply(tokenPath string) int64 {
	switch tokenPath {
	case barPath:
		return bar.TotalSupply()
	case bazPath:
		return baz.TotalSupply()
	case fooPath:
		return foo.TotalSupply()
	case quxPath:
		return qux.TotalSupply()
	case oblPath:
		return obl.TotalSupply()
	default:
		return 0
	}
}

func burnTestTokens(t *testing.T) {
	t.Helper()

	poolAddr := access.MustGetAddress(prabc.ROLE_POOL.String())
	positionAddr := access.MustGetAddress(prabc.ROLE_POSITION.String())
	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	stakerAddr := access.MustGetAddress(prabc.ROLE_STAKER.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	addrs := []address{adminAddr, poolAddr, positionAddr, protocolFeeAddr, stakerAddr}

	for _, addr := range addrs {
		bar.Burn(cross, addr, bar.BalanceOf(addr))
		baz.Burn(cross, addr, baz.BalanceOf(addr))
		foo.Burn(cross, addr, foo.BalanceOf(addr))
		qux.Burn(cross, addr, qux.BalanceOf(addr))
		obl.Burn(cross, addr, obl.BalanceOf(addr))
	}
}

// getTokenPathsFromPosition extracts token0Path and token1Path from a position's pool key
func getTokenPathsFromPosition(tokenId uint64) (string, string) {
	token0, token1, _ := getPoolInfoFromPosition(tokenId)
	return token0, token1
}

// getPoolInfoFromPosition extracts token0Path, token1Path, and fee tier from a position
func getPoolInfoFromPosition(tokenId uint64) (string, string, uint32) {
	poolKey := position.GetPositionPoolKey(tokenId)
	return parsePoolKey(poolKey)
}

// parsePoolKey parses a pool key string (format: "token0:token1:fee") and returns token0, token1, fee
func parsePoolKey(poolKey string) (string, string, uint32) {
	parts := strings.Split(poolKey, ":")
	if len(parts) != 3 {
		panic("invalid pool key format")
	}

	fee, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		panic("invalid fee value in pool key")
	}

	return parts[0], parts[1], uint32(fee)
}

// randomFutureDeadline draws a randomized future deadline using fuzz helpers
func randomFutureDeadline(ft *fuzz.T) int64 {
	bufferSeconds := fuzz.Int64Range(60, 3600).Draw(ft, "deadlineBufferSeconds").(int64)
	return time.Now().Add(time.Duration(bufferSeconds) * time.Second).Unix()
}

// defaultFutureDeadline provides a deterministic future deadline when fuzz context is unavailable
func defaultFutureDeadline() int64 {
	return time.Now().Add(24 * time.Hour).Unix()
}

// generateTokenPath generates a random token path from the default token paths
func generateTokenPath(f *fuzz.T) string {
	return generateTokenPathByList(f, defaultTokenPaths)
}

// generateTokenPair generates a random pair of different token paths
func generateTokenPair(f *fuzz.T) (string, string) {
	token0Path := generateTokenPath(f)

	currentTokenPaths := make(map[string]bool)
	for tokenPath := range defaultTokenPaths {
		if tokenPath != token0Path {
			currentTokenPaths[tokenPath] = true
		}
	}

	token1Path := generateTokenPathByList(f, currentTokenPaths)

	return token0Path, token1Path
}

// generateTokenPathByList generates a random token path from the given list
func generateTokenPathByList(f *fuzz.T, tokenPaths map[string]bool) string {
	tokenPathIndex := fuzz.IntRange(0, len(tokenPaths)-1).Draw(f, "tokenPath").(int)

	currentIndex := 0
	for tokenPath := range tokenPaths {
		if currentIndex == tokenPathIndex {
			return tokenPath
		}
		currentIndex++
	}

	return ""
}

// generateFeeTier generates a random fee tier from the default fee tiers
func generateFeeTier(f *fuzz.T) uint32 {
	feeTierIndex := fuzz.IntRange(0, len(defaultFeeTiers)-1).Draw(f, "feeTier").(int)
	return defaultFeeTiers[feeTierIndex]
}

// generateRandomTicks generates random tick lower and upper values
func generateRandomTicks(f *fuzz.T, currentTick int32, feeTier uint32) (int32, int32) {
	tickSpacing := defaultTickSpacings[feeTier]

	tickLower := currentTick - (currentTick % tickSpacing)
	tickUpper := currentTick + (currentTick % tickSpacing)

	inRangeType := fuzz.IntRange(0, 2).Draw(f, "inRangeType").(int)

	migrateTick := func(tick int32, tickSpacing int32) int32 {
		left := tick % tickSpacing
		if tick >= 0 {
			return tick - left
		} else {
			return tick + tickSpacing - left
		}
	}

	maxTick := migrateTick(MAX_TICK, tickSpacing)
	minTick := migrateTick(MIN_TICK, tickSpacing)

	switch inRangeType {
	case 0:
		tickLower = fuzz.Int32Range(minTick, currentTick-tickSpacing).Draw(f, "tickLower").(int32)
		tickUpper = fuzz.Int32Range(tickLower, currentTick-tickSpacing).Draw(f, "tickUpper").(int32)
	case 1:
		tickLower = fuzz.Int32Range(minTick, currentTick-tickSpacing).Draw(f, "tickLower").(int32)
		tickUpper = fuzz.Int32Range(currentTick+tickSpacing, maxTick).Draw(f, "tickUpper").(int32)
	case 2:
		tickUpper = fuzz.Int32Range(currentTick+tickSpacing, maxTick).Draw(f, "tickUpper").(int32)
		tickLower = fuzz.Int32Range(currentTick+tickSpacing, tickUpper-tickSpacing).Draw(f, "tickLower").(int32)
	}
	tickLower = migrateTick(tickLower, tickSpacing)
	tickUpper = migrateTick(tickUpper, tickSpacing)

	if tickLower == tickUpper {
		tickUpper = tickLower + tickSpacing
	}

	return tickLower, tickUpper
}
