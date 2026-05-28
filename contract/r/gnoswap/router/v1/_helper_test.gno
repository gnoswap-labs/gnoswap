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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/staker/v1"
)

const (
	gnsPath string = "gno.land/r/gnoswap/gns"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	fooPath string = "gno.land/r/onbloc/foo"
	oblPath string = "gno.land/r/onbloc/obl"
	quxPath string = "gno.land/r/onbloc/qux"

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
	singlePoolPath          = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
	singlePoolPath2         = "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000"
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

func TokenFaucet(cur realm, t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(cur, t, to, defaultAmount)
	case barPath:
		barTransfer(cur, t, to, defaultAmount)
	case bazPath:
		bazTransfer(cur, t, to, defaultAmount)
	case fooPath:
		fooTransfer(cur, t, to, defaultAmount)
	case oblPath:
		oblTransfer(cur, t, to, defaultAmount)
	case quxPath:
		quxTransfer(cur, t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenFaucet2(cur realm, t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(10_000_000_000)

	switch tokenPath {
	case gnsPath:
		gnsTransfer(cur, t, to, defaultAmount)
	case barPath:
		barTransfer(cur, t, to, defaultAmount)
	case bazPath:
		bazTransfer(cur, t, to, defaultAmount)
	case fooPath:
		fooTransfer(cur, t, to, defaultAmount)
	case oblPath:
		oblTransfer(cur, t, to, defaultAmount)
	case quxPath:
		quxTransfer(cur, t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenApprove(cur realm, t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case gnsPath:
		gnsApprove(cur, t, owner, spender, amount)
	case barPath:
		barApprove(cur, t, owner, spender, amount)
	case bazPath:
		bazApprove(cur, t, owner, spender, amount)
	case fooPath:
		fooApprove(cur, t, owner, spender, amount)
	case oblPath:
		oblApprove(cur, t, owner, spender, amount)
	case quxPath:
		quxApprove(cur, t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func CreatePool(cur realm, t *testing.T,
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
		pl.CreatePool(cross(cur), token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTier(cross(cur), poolPath, TIER_1)
	}
}

func gnsApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	gns.Approve(cross(cur), spender, amount)
}

func barApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	bar.Approve(cross(cur), spender, amount)
}

func bazApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	baz.Approve(cross(cur), spender, amount)
}

func fooApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	foo.Approve(cross(cur), spender, amount)
}

func oblApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	obl.Approve(cross(cur), spender, amount)
}

func quxApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	qux.Approve(cross(cur), spender, amount)
}

func gnsTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	gns.Transfer(cross(cur), to, amount)
}

func barTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	bar.Transfer(cross(cur), to, amount)
}

func bazTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	baz.Transfer(cross(cur), to, amount)
}

func fooTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	foo.Transfer(cross(cur), to, amount)
}

func oblTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	obl.Transfer(cross(cur), to, amount)
}

func quxTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	qux.Transfer(cross(cur), to, amount)
}

func CreatePoolWithoutFee(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	// set pool create fee to 0 for testing
	pl.SetPoolCreationFee(cross(cur), 0)
	CreatePool(cur, t, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(cur, t, bazPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(cur, t, barPath, bazPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(cur, t, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
}

func CreateSecondPoolWithoutFee(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	CreatePool(cur, t,
		bazPath,
		quxPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		admin,
	)
}

func MakeMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(cur, t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross(cur),
		barPath,
		bazPath,
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

func MakeSecondMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(cur, t, bazPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, quxPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross(cur),
		bazPath,
		quxPath,
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

func MakeThirdMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(cur, t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, fooPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross(cur),
		barPath,
		fooPath,
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

func MakeForthMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(cur, t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross(cur),
		barPath,
		bazPath,
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
		func(cur realm) {
			pl.RegisterInitializer(cross(cur), func(_ pl.IPoolStore) pl.IPool {
				return pool_v1.NewPoolV1(mock.NewMockPoolStore())
			})
		}(cross1)
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	func(cur realm) {
		pl.UpgradeImpl(cross(cur), mockPoolPath)
	}(cross1)
}

// registerPositionTest registers the position mock implementation
func registerPositionTest(t *testing.T) {
	t.Helper()

	positionMockPath := "gno.land/r/gnoswap/position/mock"

	if registeredTestStore {
		testing.SetRealm(adminRealm)
		func(cur realm) {
			pn.UpgradeImpl(cross(cur), positionMockPath)
		}(cross1)
		return
	}

	testing.SetRealm(testing.NewCodeRealm(positionMockPath))
	func(cur realm) {
		pn.RegisterInitializer(cross(cur), func(_ pn.IPositionStore) pn.IPosition {
			return position_v1.NewPositionV1(newMockPositionStore(), newMockNFTAccessor())
		})
	}(cross1)

	testing.SetRealm(adminRealm)
	func(cur realm) {
		pn.UpgradeImpl(cross(cur), positionMockPath)
	}(cross1)
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
		return mockInstance.SwapCallback(0, cur, token0Path, token1Path, amount0DeltaInt64, amount1DeltaInt64, payer)
	}(cross1)
}
