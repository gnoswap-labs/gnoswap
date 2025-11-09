package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"
	router_v1 "gno.land/r/gnoswap/router/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const FUZZ_ITERATIONS = 10

const (
	MIN_SQRT_RATIO = "4295128739"
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"

	MIN_TICK = int32(-887272)
	MAX_TICK = int32(887272)

	// Token paths
	BAR_PATH = "gno.land/r/onbloc/bar"
	FOO_PATH = "gno.land/r/onbloc/foo"
	BAZ_PATH = "gno.land/r/onbloc/baz"
)

var (
	VALID_FEE_TIERS = []uint32{100, 500, 3000, 10000}
)

var (
	adminAddr = access.MustGetAddress(prabc.ROLE_ADMIN.String())

	initializedPool     = false
	initializedPosition = false
	initializedRouter   = false
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
)

// initStates initializes the states for the fuzz test
func initStates(t *testing.T) {
	burnTestTokens(t)

	initPoolState(t)
	initPositionState(t)
	initRouterState(t)
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
			return position_v1.NewPositionV1(newMockPositionStore(), newMockNFTAccessor())
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

func mintTestToken(tokenPath string, amount int64) {
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

// getRandomTokenPair returns a random token pair from available test tokens
func getRandomTokenPair(ft *fuzz.T) (token0Path, token1Path string) {
	// Available tokens
	availableTokens := []string{
		barPath,
		bazPath,
		fooPath,
		quxPath,
		oblPath,
	}

	// Select two different random tokens
	index0 := fuzz.IntRange(0, len(availableTokens)-1).Draw(ft, "tokenIndex0").(int)
	index1 := fuzz.IntRange(0, len(availableTokens)-1).Draw(ft, "tokenIndex1").(int)

	// Ensure tokens are different
	for index0 == index1 {
		index1 = fuzz.IntRange(0, len(availableTokens)-1).Draw(ft, "tokenIndex1Retry").(int)
	}

	token0Path = availableTokens[index0]
	token1Path = availableTokens[index1]

	// Ensure token0 < token1 (canonical ordering)
	if token0Path > token1Path {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path, token1Path
}
