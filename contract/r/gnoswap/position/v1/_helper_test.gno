package v1

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/mock"

	"gno.land/r/gnoswap/pool"
	pl "gno.land/r/gnoswap/pool"
	pool_v1 "gno.land/r/gnoswap/pool/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"
	"gno.land/r/gnoswap/test_token/eth"
	"gno.land/r/gnoswap/test_token/sol"
	"gno.land/r/gnoswap/test_token/usdc"

	"gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/staker/v1"
)

const (
	gnotDenom  string = "ugnot"
	wugnotPath string = "gno.land/r/gnoland/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/gns"
	atomPath    string = "gno.land/r/gnoswap/test_token/atom"
	atonePath    string = "gno.land/r/gnoswap/test_token/atone"
	btcPath    string = "gno.land/r/gnoswap/test_token/btc"
	ethPath    string = "gno.land/r/gnoswap/test_token/eth"
	solPath    string = "gno.land/r/gnoswap/test_token/sol"

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
	positionAddr = rbac.DefaultRoleAddresses[prabc.ROLE_POSITION]
	stakerAddr   = rbac.DefaultRoleAddresses[prabc.ROLE_STAKER]

	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminAddr  = rbac.DefaultRoleAddresses[prabc.ROLE_ADMIN]
	adminRealm = testing.NewUserRealm(adminAddr)

	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	emissionAddr    = rbac.DefaultRoleAddresses[prabc.ROLE_EMISSION]
	poolAddr        = rbac.DefaultRoleAddresses[prabc.ROLE_POOL]
	protocolFeeAddr = rbac.DefaultRoleAddresses[prabc.ROLE_PROTOCOL_FEE]
	routerAddr      = rbac.DefaultRoleAddresses[prabc.ROLE_ROUTER]
	devOpsAddr      = rbac.DefaultRoleAddresses[prabc.ROLE_DEVOPS]

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	rouPath  = "gno.land/r/gnoswap/router"
	rouRealm = testing.NewCodeRealm(rouPath)

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	mockInstance        *positionV1
	mockPoolStore       *mock.MockPoolStore
	registeredTestStore = false

	initializedPool = false
)

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case wugnotPath:
		wugnotTransfer(t, to, defaultAmount)
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

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		return wugnot.BalanceOf(owner)
	case gnsPath:
		return gns.BalanceOf(owner)
	case atomPath:
		return atom.BalanceOf(owner)
	case atonePath:
		return atone.BalanceOf(owner)
	case btcPath:
		return btc.BalanceOf(owner)
	case ethPath:
		return eth.BalanceOf(owner)
	case solPath:
		return sol.BalanceOf(owner)
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
	case atomPath:
		return atom.Allowance(owner, spender)
	case atonePath:
		return atone.Allowance(owner, spender)
	case btcPath:
		return btc.Allowance(owner, spender)
	case ethPath:
		return eth.Allowance(owner, spender)
	case solPath:
		return sol.Allowance(owner, spender)
	default:
		panic("token not found")
	}
}

func TokenApprove(t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		wugnotApprove(t, owner, spender, amount)
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
	}
}

// set pool create fee to 0 for testing
func CreatePoolWithoutFee(t *testing.T) {
	t.Helper()
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(t, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), adminAddr)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	TokenApprove(t, atomPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, btcPath, adminAddr, poolAddr, maxApprove)

	testing.SetRealm(adminRealm)

	// mint position
	return func(cur realm) (uint64, string, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.Mint(
			atomPath,
			btcPath,
			fee500,
			-887270,
			887270,
			"50000",
			"50000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			"",
		)
	}(cross)
}

func LPTokenApprove(t *testing.T, owner, operator address, positionId uint64) {
	t.Helper()
	testing.SetOriginCaller(owner)
	gnft.Approve(cross, operator, positionIdFrom(positionId))
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

func wugnotApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	wugnot.Approve(cross, spender, amount)
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

func wugnotTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	wugnot.Transfer(cross, to, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, to, amount)
}

func atomTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	atom.Transfer(cross, to, amount)
}

func atoneTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	atone.Transfer(cross, to, amount)
}

func btcTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	btc.Transfer(cross, to, amount)
}

func ethTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	eth.Transfer(cross, to, amount)
}

func solTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	sol.Transfer(cross, to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to address, amount int64) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(from))
	testing.SetOriginSend(chain.Coins{{gnotDenom, amount}})
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(from, to, chain.Coins{{gnotDenom, amount}})
}

func ugnotBalanceOf(t *testing.T, addr address) int64 {
	t.Helper()

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
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

func ugnotBurn(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	banker_.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to address, amount int64) {
	t.Helper()
	faucetAddress := adminAddr
	testing.SetOriginCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := chain.Coins{{gnotDenom, amount}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		testing.SetOriginSend(newCoins)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func burnTokens(t *testing.T) {
	t.Helper()

	// burn tokens
	for _, addr := range addrUsedInTest {
		burnBtc(addr)
		burnAtom(addr)
		burnAtone(addr)
		burnSol(addr)
		burnEth(addr)
		burnUsdc(addr)
	}
}

func burnBtc(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	btc.Burn(cross, addr, btc.BalanceOf(addr))
}

func burnAtom(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	atom.Burn(cross, addr, atom.BalanceOf(addr))
}

func burnAtone(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	atone.Burn(cross, addr, atone.BalanceOf(addr))
}

func burnSol(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	sol.Burn(cross, addr, sol.BalanceOf(addr))
}

func burnEth(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	eth.Burn(cross, addr, eth.BalanceOf(addr))
}

func burnUsdc(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	usdc.Burn(cross, addr, usdc.BalanceOf(addr))
}

func initPoolTest(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"
	mockPoolStore = mock.NewMockPoolStore()

	if !initializedPool {
		initializedPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pool.RegisterInitializer(cross, func(_ pool.IPoolStore) pool.IPool {
			return pool_v1.NewPoolV1(mockPoolStore)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.UpgradeImpl(cross, mockPoolPath)
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

func initPositionTest(t *testing.T) {
	t.Helper()
	initPoolTest(t)
	mockInstance = &positionV1{
		store:       mock.NewMockPositionStore(),
		nftAccessor: mock.NewMockNFTAccessor(),
	}
}

// set pool create fee to 0 for testing
func createPoolWithoutFee(token0 string, token1 string, fee uint32, tick int32) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	pl.CreatePool(cross, token0, token1, fee, common.TickMathGetSqrtRatioAtTick(tick).ToString())
}

func mockInstanceMint(
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
	common.SafeGRC20Approve(cross, token0, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross, token1, poolAddr, amount1Int)

	return func(cur realm) (uint64, string, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.Mint(
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
	}(cross)
}

func mockInstanceIncreaseLiquidity(
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
	common.SafeGRC20Approve(cross, atomPath, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross, btcPath, poolAddr, amount1Int)

	return func(cur realm) (uint64, string, string, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.IncreaseLiquidity(
			positionId,
			amount0DesiredStr,
			amount1DesiredStr,
			amount0MinStr,
			amount1MinStr,
			deadline,
		)
	}(cross)
}

func mockInstanceDecreaseLiquidity(
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string, string, string) {
	return func(cur realm) (uint64, string, string, string, string, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.DecreaseLiquidity(
			positionId,
			liquidityStr,
			amount0MinStr,
			amount1MinStr,
			deadline,
		)
	}(cross)
}

func mockInstanceReposition(
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
	common.SafeGRC20Approve(cross, atomPath, poolAddr, amount0Int)
	common.SafeGRC20Approve(cross, btcPath, poolAddr, amount1Int)

	return func(cur realm) (uint64, string, int32, int32, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.Reposition(
			positionId,
			tickLower,
			tickUpper,
			amount0DesiredStr,
			amount1DesiredStr,
			amount0MinStr,
			amount1MinStr,
			deadline,
		)
	}(cross)
}

func mockInstanceCollectFee(
	positionId uint64,
	caller address,
) (uint64, string, string, string, string, string) {
	testing.SetRealm(testing.NewUserRealm(caller))

	return func(cur realm) (uint64, string, string, string, string, string) {
		testing.SetRealm(testing.NewCodeRealm(posPath))
		return mockInstance.CollectFee(positionId)
	}(cross)
}
