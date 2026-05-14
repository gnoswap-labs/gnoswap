package v1

import (
	"chain"
	"strconv"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/mock"
	pl "gno.land/r/gnoswap/pool"
	pool_v1 "gno.land/r/gnoswap/pool/v1"
	pn "gno.land/r/gnoswap/position"
	position_v1 "gno.land/r/gnoswap/position/v1"
	sr "gno.land/r/gnoswap/staker"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/sol"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/staker/v1"
)

const (
	gnsPath string = "gno.land/r/gnoswap/gns"
	atomPath string = "gno.land/r/gnoswap/test_token/atom"
	atonePath string = "gno.land/r/gnoswap/test_token/atone"
	btcPath string = "gno.land/r/gnoswap/test_token/btc"
	ethPath string = "gno.land/r/gnoswap/test_token/eth"
	solPath string = "gno.land/r/gnoswap/test_token/sol"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
	maxApprove  int64 = 9223372036854775807

	TIER_1 uint64 = 1
	TIER_2 uint64 = 2
	TIER_3 uint64 = 3

	poolCreationFee = 100_000_000
)

const (
	FEE_LOW    uint32 = 500
	FEE_MEDIUM uint32 = 3000
	FEE_HIGH   uint32 = 10000
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	user1Addr       address = testutils.TestAddress("user1")
	user2Addr       address = testutils.TestAddress("user2")
	singlePoolPath          = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000"
	singlePoolPath2         = "gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:3000"
)

var (
	minTick  int32 = -887220
	maxTick  int32 = 887220
	deadline int64 = max_timeout
)

var (
	admin, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminAddr = admin

	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	adminRealm = testing.NewUserRealm(admin)

	routerPath  = "gno.land/r/gnoswap/router"
	routerRealm = testing.NewCodeRealm(routerPath)

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	poolAddr     = chain.PackageAddress("gno.land/r/gnoswap/pool")
	routerAddr   = chain.PackageAddress("gno.land/r/gnoswap/router")
	positionAddr = chain.PackageAddress("gno.land/r/gnoswap/position")

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	registeredTestStore = false
	registeredTestPool  = false

	mockInstance *routerV1
)

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case atomPath:
		atomTransfer(t, to, defaultAmount)
	case atonePath:
		atoneTransfer(t, to, defaultAmount)
	case btcPath:
		btcTransfer(t, to, defaultAmount)
	case ethPath:
		ethTransfer(t, to, defaultAmount)
	case solPath:
		solTransfer(t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenFaucet2(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(10_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case atomPath:
		atomTransfer(t, to, defaultAmount)
	case atonePath:
		atoneTransfer(t, to, defaultAmount)
	case btcPath:
		btcTransfer(t, to, defaultAmount)
	case ethPath:
		ethTransfer(t, to, defaultAmount)
	case solPath:
		solTransfer(t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenApprove(t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		gnsApprove(t, owner, spender, amount)
	case atomPath:
		atomApprove(t, owner, spender, amount)
	case atonePath:
		atoneApprove(t, owner, spender, amount)
	case btcPath:
		btcApprove(t, owner, spender, amount)
	case ethPath:
		ethApprove(t, owner, spender, amount)
	case solPath:
		solApprove(t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func CreatePool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTier(cross, poolPath, TIER_1)
	}
}

func gnsApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	gns.Approve(cross, spender, amount)
}

func atomApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atom.Approve(cross, spender, amount)
}

func atoneApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	atone.Approve(cross, spender, amount)
}

func btcApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	btc.Approve(cross, spender, amount)
}

func ethApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	eth.Approve(cross, spender, amount)
}

func solApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	sol.Approve(cross, spender, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	gns.Transfer(cross, to, amount)
}

func atomTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	atom.Transfer(cross, to, amount)
}

func atoneTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	atone.Transfer(cross, to, amount)
}

func btcTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	btc.Transfer(cross, to, amount)
}

func ethTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	eth.Transfer(cross, to, amount)
}

func solTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	sol.Transfer(cross, to, amount)
}


func CreatePoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	// set pool create fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(t, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, atonePath, btcPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, atomPath, atonePath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, atomPath, atonePath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
}

func CreateSecondPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	CreatePool(t,
		atonePath,
		solPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		admin,
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, atomPath, admin, poolAddr, maxApprove)
	TokenApprove(t, atonePath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		"",
	)
}

func MakeSecondMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(t, atonePath, admin, poolAddr, maxApprove)
	TokenApprove(t, solPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross,
		atonePath,
		solPath,
		fee3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		"",
	)
}

func MakeThirdMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(t, atomPath, admin, poolAddr, maxApprove)
	TokenApprove(t, btcPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		"",
	)
}

func MakeForthMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, atomPath, admin, poolAddr, maxApprove)
	TokenApprove(t, atonePath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		"",
	)
}

func initRouterTest(t *testing.T) {
	t.Helper()

	initPoolTest(t)
	registerPositionTest(t)

	registeredTestStore = true

	mockInstance = &routerV1{
		store: mock.NewMockRouterStore(),
	}
}

func initPoolTest(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !registeredTestPool {
		registeredTestPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pl.RegisterInitializer(cross, func(_ pl.IPoolStore) pl.IPool {
			return pool_v1.NewPoolV1(mock.NewMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.UpgradeImpl(cross, mockPoolPath)
}

// registerPositionTest registers the position mock implementation
func registerPositionTest(t *testing.T) {
	t.Helper()

	positionMockPath := "gno.land/r/gnoswap/position/mock"

	if registeredTestStore {
		testing.SetRealm(adminRealm)
		pn.UpgradeImpl(cross, positionMockPath)
		return
	}

	testing.SetRealm(testing.NewCodeRealm(positionMockPath))
	func() {
		pn.RegisterInitializer(cross, func(_ pn.IPositionStore) pn.IPosition {
			return position_v1.NewPositionV1(newMockPositionStore(), newMockNFTAccessor())
		})
	}()

	testing.SetRealm(adminRealm)
	pn.UpgradeImpl(cross, positionMockPath)
}

// mockInstanceSwapCallback is a helper function to call the SwapCallback function on the mock instance
func mockInstanceSwapCallback(
	token0Path string,
	token1Path string,
	amount0Delta string,
	amount1Delta string,
	payer address,
) error {
	amount0DeltaInt64, err := strconv.ParseInt(amount0Delta, 10, 64)
	if err != nil {
		return err
	}
	amount1DeltaInt64, err := strconv.ParseInt(amount1Delta, 10, 64)
	if err != nil {
		return err
	}
	// mock instance using a closure
	return func(cur realm) error {
		testing.SetRealm(testing.NewCodeRealm(routerPath))
		return mockInstance.SwapCallback(token0Path, token1Path, amount0DeltaInt64, amount1DeltaInt64, payer)
	}(cross)
}
