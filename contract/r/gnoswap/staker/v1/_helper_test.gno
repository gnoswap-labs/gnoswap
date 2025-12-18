package v1

import (
	"chain"
	"chain/banker"
	"math"
	"testing"

	"gno.land/p/nt/testutils"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/mock"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
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

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	maxApprove  int64  = 9223372036854775806
	max_timeout int64  = 9999999999

	stakerPackagePath string = "gno.land/r/gnoswap/staker"
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminRealm = testing.NewUserRealm(adminAddr)

	alice = testutils.TestAddress("alice")

	govGovernanceAddr = access.MustGetAddress(prbac.ROLE_GOVERNANCE.String())
	poolAddr          = access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr        = access.MustGetAddress(prbac.ROLE_ROUTER.String())
	emissionAddr      = access.MustGetAddress(prbac.ROLE_EMISSION.String())

	posRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/position")
	rouRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = testing.NewUserRealm(dummyAddr)

	mockInstance     *stakerV1
	mockGNFTAccessor = newMockNFTAccessor()

	initializedPool     bool
	initializedPosition bool
)

func CreatePool(
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
	}
}

func LPTokenStake(t *testing.T, owner address, positionId uint64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
}

func LPTokenUnStake(t *testing.T, owner address, positionId uint64, unwrap bool) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
}

func CreateSecondPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	CreatePool(
		barPath,
		bazPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		adminAddr,
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, barPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(t, bazPath, adminAddr, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
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
		adminAddr,
		adminAddr,
		"",
	)
}

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case wugnotPath:
		wugnotTransfer(t, to, defaultAmount)
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case barPath:
		barTransfer(t, to, defaultAmount)
	case bazPath:
		bazTransfer(t, to, defaultAmount)
	case fooPath:
		fooTransfer(t, to, defaultAmount)
	case oblPath:
		oblTransfer(t, to, defaultAmount)
	case quxPath:
		quxTransfer(t, to, defaultAmount)
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

func TokenApprove(t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		wugnotApprove(t, owner, spender, amount)
	case gnsPath:
		gnsApprove(t, owner, spender, amount)
	case barPath:
		barApprove(t, owner, spender, amount)
	case bazPath:
		bazApprove(t, owner, spender, amount)
	case fooPath:
		fooApprove(t, owner, spender, amount)
	case oblPath:
		oblApprove(t, owner, spender, amount)
	case quxPath:
		quxApprove(t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func MintPosition(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string, // *u256.Uint
	amount1Desired string, // *u256.Uint
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
	mintTo address,
	caller address,
) (uint64, string, string, string) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(caller))

	return pn.Mint(
		cross,
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
		caller,
		"",
	)
}

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

func barApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	bar.Approve(cross, spender, amount)
}

func bazApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	baz.Approve(cross, spender, amount)
}

func fooApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	foo.Approve(cross, spender, amount)
}

func oblApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	obl.Approve(cross, spender, amount)
}

func quxApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	qux.Approve(cross, spender, amount)
}

func wugnotTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	wugnot.Transfer(cross, to, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, to, amount)
}

func barTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, to, amount)
}

func bazTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	baz.Transfer(cross, to, amount)
}

func fooTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	foo.Transfer(cross, to, amount)
}

func oblTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	obl.Transfer(cross, to, amount)
}

func quxTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(adminRealm)
	qux.Transfer(cross, to, amount)
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

func ugnotDeposit(t *testing.T, addr address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(addr))
	wugnotAddr := chain.PackageAddress(wugnotPath)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(addr, wugnotAddr, chain.Coins{{gnotDenom, amount}})
	wugnot.Deposit(cross)
}

type gnsBalanceTracker struct {
	height               int64
	stakerBalance        uint64
	devOpsBalance        uint64
	communityPoolBalance uint64
	govStakerBalance     uint64
	protocolFeeBalance   uint64
	callerBalance        uint64
}

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected uint64, actual uint64) bool {
	maxSafeValue := uint64(math.MaxUint64 / 100001)
	var lowerBound, upperBound uint64
	if expected > maxSafeValue {
		lowerBound = expected / 100000 * 99999
		upperBound = expected / 100000 * 100001
	} else {
		lowerBound = expected * 99999 / 100000
		upperBound = expected * 100001 / 100000
	}
	return actual >= lowerBound && actual <= upperBound
}

func initStakerTest(t *testing.T) {
	t.Helper()

	mockGNFTAccessor = newMockNFTAccessor()

	initPoolTest(t)
	initPositionTest(t)

	mockInstance = &stakerV1{
		store:            newMockStakerStore(),
		poolAccessor:     newMockPoolAccessor(),
		emissionAccessor: newMockEmissionAccessor(),
		nftAccessor:      mockGNFTAccessor,
	}
}

func initPoolTest(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true
		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pl.RegisterInitializer(cross, func(s pl.IPoolStore) pl.IPool {
			return pool_v1.NewPoolV1(mock.NewMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.UpgradeImpl(cross, mockPoolPath)
}

func initPositionTest(t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true
		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		pn.RegisterInitializer(cross, func(s pn.IPositionStore) pn.IPosition {
			return position_v1.NewPositionV1(mock.NewMockPositionStore(), mockGNFTAccessor)
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pn.UpgradeImpl(cross, mockPositionPath)
}

func getMockInstance() *stakerV1 {
	if mockInstance == nil {
		mockInstance = &stakerV1{
			store:            newMockStakerStore(),
			poolAccessor:     newMockPoolAccessor(),
			emissionAccessor: newMockEmissionAccessor(),
			nftAccessor:      mockGNFTAccessor,
		}
	}

	return mockInstance
}

func mockInstanceSetDepositGnsAmount(amount int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetDepositGnsAmount(amount)
	}(cross)
}

func mockInstanceSetMinimumRewardAmount(amount int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetMinimumRewardAmount(amount)
	}(cross)
}

func mockInstanceStakeToken(positionId uint64, referrer string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().StakeToken(positionId, referrer)
	}(cross)
}

func mockInstanceCollectReward(positionId uint64, unwrapResult bool) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().CollectReward(positionId, unwrapResult)
	}(cross)
}

func mockInstanceAddToken(tokenPath string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().AddToken(tokenPath)
	}(cross)
}

func mockInstanceRemoveToken(tokenPath string) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().RemoveToken(tokenPath)
	}(cross)
}

func mockInstanceSetUnstakingFee(fee int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetUnStakingFee(fee)
	}(cross)
}

func mockInstanceCreateExternalIncentive(poolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().CreateExternalIncentive(poolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp)
	}(cross)
}

func mockInstanceSetPoolTier(poolPath string, tier uint64) {
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetPoolTier(poolPath, tier)
	}(cross)
}

func mockInstanceSetWarmupPeriod(poolPath string, warmupPeriod int64) {
	// SetWarmUp is a global function that takes percentage and time duration
	// For test purposes, we'll use 30% and the provided warmup period as duration
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		getMockInstance().SetWarmUp(30, warmupPeriod)
	}(cross)
}

func mockInstanceUnStakeToken(positionId uint64, unwrapResult bool) string {
	var poolPath string
	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
		poolPath = getMockInstance().UnStakeToken(positionId, unwrapResult)
	}(cross)
	return poolPath
}

func getPositionOperator(positionId uint64) address {
	testing.SetRealm(adminRealm)
	return pn.GetPositionOperator(positionId)
}
