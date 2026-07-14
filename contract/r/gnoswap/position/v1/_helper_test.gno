package v1

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prabc "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/mock"

	"gno.land/r/gnoswap/pool"
	pl "gno.land/r/gnoswap/pool"
	pool_v1 "gno.land/r/gnoswap/pool/v1"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	usdc "gno.land/r/gnoswap/test_token/test_usdc"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	gnotDenom  string = "ugnot"
	wugnotPath string = "gno.land/r/gnoland/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/gns"
	barPath    string = "gno.land/r/onbloc/bar"
	bazPath    string = "gno.land/r/onbloc/baz"
	fooPath    string = "gno.land/r/onbloc/foo"
	oblPath    string = "gno.land/r/onbloc/obl"
	quxPath    string = "gno.land/r/onbloc/qux"

	fee100               uint32 = 100
	fee500               uint32 = 500
	fee3000              uint32 = 3000
	fee10000             uint32 = 10000
	maxApprove           int64  = 9223372036854775806
	max_timeout          int64  = 9999999999
	maxSqrtPriceLimitX96 string = "1461446703485210103287273052203988822378723970341"
	maxUint256Minus12           = "115792089237316195423570985008687907853269984665640564039457584007913129639923"
	maxUint256Minus3            = "115792089237316195423570985008687907853269984665640564039457584007913129639932"
	maxUint256Minus2            = "115792089237316195423570985008687907853269984665640564039457584007913129639933"

	TIER_1 uint64 = 1
	TIER_2 uint64 = 2
	TIER_3 uint64 = 3
)

var (
	positionAddr = access.MustGetAddress(prabc.ROLE_POSITION.String())
	stakerAddr   = access.MustGetAddress(prabc.ROLE_STAKER.String())

	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminAddr  = access.MustGetAddress(prabc.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	emissionAddr    = access.MustGetAddress(prabc.ROLE_EMISSION.String())
	poolAddr        = access.MustGetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr = access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr      = access.MustGetAddress(prabc.ROLE_ROUTER.String())
	devOpsAddr      = access.MustGetAddress(prabc.ROLE_DEVOPS.String())

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	mockInstance        *positionV1
	mockPoolStore       *mock.MockPoolStore
	registeredTestStore = false

	initializedPool          = false
	initializedPositionProxy = false
)

func TokenFaucet(cur realm, t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case wugnotPath:
		wugnotTransfer(cur, t, to, defaultAmount)
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

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		return wugnot.BalanceOf(owner)
	case gnsPath:
		return gns.BalanceOf(owner)
	case barPath:
		return bar.BalanceOf(owner)
	case bazPath:
		return baz.BalanceOf(owner)
	case fooPath:
		return foo.BalanceOf(owner)
	case oblPath:
		return obl.BalanceOf(owner)
	case quxPath:
		return qux.BalanceOf(owner)
	default:
		panic("token not found")
	}
}

func TokenAllowance(t *testing.T, tokenPath string, owner, spender address) int64 {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		return wugnot.Allowance(owner, spender)
	case gnsPath:
		return gns.Allowance(owner, spender)
	case barPath:
		return bar.Allowance(owner, spender)
	case bazPath:
		return baz.Allowance(owner, spender)
	case fooPath:
		return foo.Allowance(owner, spender)
	case oblPath:
		return obl.Allowance(owner, spender)
	case quxPath:
		return qux.Allowance(owner, spender)
	default:
		panic("token not found")
	}
}

func TokenApprove(cur realm, t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		wugnotApprove(cur, t, owner, spender, amount)
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
	}
}

// set pool create fee to 0 for testing
func CreatePoolWithoutFee(cur realm, t *testing.T) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.SetPoolCreationFee(cross(cur), 0)
	CreatePool(cur, t, barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
}

func MakeMintPositionWithoutFee(cur realm, t *testing.T) (uint64, string, string, string) {
	t.Helper()

	return mockInstanceMint(
		cur,
		barPath,
		fooPath,
		fee500,
		-887270,
		887270,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)
}

func LPTokenApprove(cur realm, t *testing.T, owner, operator address, positionId uint64) {
	t.Helper()
	testing.SetOriginCaller(owner)
	gnft.Approve(cross(cur), operator, positionIdFrom(positionId))
}

// func LPTokenStake(t *testing.T, owner std.Address, positionId uint64) {
// 	t.Helper()
// 	testing.SetRealm(std.NewUserRealm(owner))
// 	sr.StakeToken(positionId, "")
// }

// func LPTokenUnStake(t *testing.T, owner std.Address, positionId uint64, unwrap bool) {
// 	t.Helper()
// 	testing.SetRealm(std.NewUserRealm(owner))
// 	sr.UnStakeToken(positionId, unwrap)
// }

func wugnotApprove(cur realm, t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	wugnot.Approve(cross(cur), spender, amount)
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

func wugnotTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	wugnot.Transfer(cross(cur), to, amount)
}

func gnsTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross(cur), to, amount)
}

func barTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	bar.Transfer(cross(cur), to, amount)
}

func bazTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	baz.Transfer(cross(cur), to, amount)
}

func fooTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	foo.Transfer(cross(cur), to, amount)
}

func oblTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	obl.Transfer(cross(cur), to, amount)
}

func quxTransfer(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	qux.Transfer(cross(cur), to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(cur realm, t *testing.T, from, to address, amount int64) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(from))
	testing.SetOriginSend(chain.Coins{{gnotDenom, amount}})
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend, cur)
	banker_.SendCoins(from, to, chain.Coins{{gnotDenom, amount}})
}

func ugnotBalanceOf(cur realm, t *testing.T, addr address) int64 {
	t.Helper()

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue, cur)
	coins := banker_.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return coins.AmountOf(gnotDenom)
}

func ugnotMint(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	testing.IssueCoins(addr, chain.Coins{{denom, amount}})
}

func ugnotBurn(cur realm, t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue, cur)
	banker_.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(cur realm, t *testing.T, to address, amount int64) {
	t.Helper()
	faucetAddress := adminAddr
	testing.SetOriginCaller(faucetAddress)

	if ugnotBalanceOf(cur, t, faucetAddress) < amount {
		newCoins := chain.Coins{{gnotDenom, amount}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		testing.SetOriginSend(newCoins)
	}
	ugnotTransfer(cur, t, faucetAddress, to, amount)
}

func burnTokens(cur realm, t *testing.T) {
	t.Helper()

	// burn tokens
	for _, addr := range addrUsedInTest {
		burnFoo(cur, addr)
		burnBar(cur, addr)
		burnBaz(cur, addr)
		burnQux(cur, addr)
		burnObl(cur, addr)
		burnUsdc(cur, addr)
	}
}

func burnFoo(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	foo.Burn(cross(cur), addr, foo.BalanceOf(addr))
}

func burnBar(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	bar.Burn(cross(cur), addr, bar.BalanceOf(addr))
}

func burnBaz(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	baz.Burn(cross(cur), addr, baz.BalanceOf(addr))
}

func burnQux(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	qux.Burn(cross(cur), addr, qux.BalanceOf(addr))
}

func burnObl(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	obl.Burn(cross(cur), addr, obl.BalanceOf(addr))
}

func burnUsdc(cur realm, addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	usdc.Burn(cross(cur), addr, usdc.BalanceOf(addr))
}

func initPoolTest(cur realm, t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"
	mockPoolStore = mock.NewMockPoolStore()

	if !initializedPool {
		initializedPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pool.RegisterInitializer(cross(cur), func(_ int, rlm realm, _ pool.IPoolStore) pool.IPool {
			return pool_v1.NewPoolV1(mockPoolStore)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.UpgradeImpl(cross(cur), mockPoolPath)
}

func mustGetStoredTestPool(poolPath string) *pl.Pool {
	pools := mockPoolStore.GetPools()
	poolValue, ok := pools.Get(poolPath)
	if !ok {
		panic("test pool not found")
	}

	storedPool, ok := poolValue.(*pl.Pool)
	if !ok {
		panic("failed to cast test pool")
	}

	return storedPool
}

func initPositionTest(cur realm, t *testing.T) {
	t.Helper()
	initPoolTest(cur, t)
	mockInstance = &positionV1{
		store:       mock.NewMockPositionStore(),
		nftAccessor: mock.NewMockNFTAccessor(),
	}
	initPositionProxyTest(cur, t)
}

func initPositionProxyTest(cur realm, t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPositionProxy {
		initializedPositionProxy = true

		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		position.RegisterInitializer(cross(cur), func(_ int, rlm realm, positionStore position.IPositionStore) position.IPosition {
			return mockInstance
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	position.UpgradeImpl(cross(cur), mockPositionPath)
}

// set pool create fee to 0 for testing
func createPoolWithoutFee(cur realm, token0 string, token1 string, fee uint32, tick int32) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)
	pl.CreatePool(cross(cur), token0, token1, fee, gnsmath.TickMathGetSqrtRatioAtTick(tick).ToString())
}

func mockInstanceMint(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	mintTo address,
	caller address,
	referrer string,
) (uint64, string, string, string) {
	amount0Int, _ := strconv.ParseInt(amount0Desired, 10, 64)
	amount1Int, _ := strconv.ParseInt(amount1Desired, 10, 64)

	testing.SetRealm(testing.NewUserRealm(caller))
	common.SafeGRC20Approve(cross(cur), token0, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross(cur), token1, poolAddr, amount1Int)

	testing.SetRealm(testing.NewUserRealm(caller))
	return position.Mint(cross(cur),
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
		mintTo,
		referrer,
	)
}

func mockInstanceIncreaseLiquidity(
	cur realm,
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	caller address,
) (uint64, string, string, string, string) {
	amount0Int, _ := strconv.ParseInt(amount0DesiredStr, 10, 64)
	amount1Int, _ := strconv.ParseInt(amount1DesiredStr, 10, 64)

	testing.SetRealm(testing.NewUserRealm(caller))
	common.SafeGRC20Approve(cross(cur), barPath, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross(cur), fooPath, poolAddr, amount1Int)

	testing.SetRealm(testing.NewUserRealm(caller))
	return position.IncreaseLiquidity(cross(cur),
		positionId,
		amount0DesiredStr,
		amount1DesiredStr,
		amount0MinStr,
		amount1MinStr,
		deadline,
	)
}

func mockInstanceDecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string, string, string) {
	return position.DecreaseLiquidity(cross(cur),
		positionId,
		liquidityStr,
		amount0MinStr,
		amount1MinStr,
		deadline,
	)
}

func mockInstanceReposition(
	cur realm,
	positionId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	caller address,
) (uint64, string, int32, int32, string, string) {
	amount0Int, _ := strconv.ParseInt(amount0DesiredStr, 10, 64)
	amount1Int, _ := strconv.ParseInt(amount1DesiredStr, 10, 64)

	testing.SetRealm(testing.NewUserRealm(caller))
	common.SafeGRC20Approve(cross(cur), barPath, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross(cur), fooPath, poolAddr, amount1Int)

	testing.SetRealm(testing.NewUserRealm(caller))
	return position.Reposition(cross(cur),
		positionId,
		tickLower,
		tickUpper,
		amount0DesiredStr,
		amount1DesiredStr,
		amount0MinStr,
		amount1MinStr,
		deadline,
	)
}

func mockInstanceCollectFee(
	cur realm,
	positionId uint64,
	caller address,
) (uint64, string, string, string, string, string) {
	testing.SetRealm(testing.NewUserRealm(caller))

	return position.CollectFee(cross(cur), positionId)
}
