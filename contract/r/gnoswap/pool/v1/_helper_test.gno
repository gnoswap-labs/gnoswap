package v1

import (
	"chain"
	"testing"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/mock"
	pl "gno.land/r/gnoswap/pool"
	usdc "gno.land/r/gnoswap/test_token/test_usdc"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"

	bptree "gno.land/p/nt/bptree/v0"
	testutils "gno.land/p/nt/testutils/v0"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	uassert "gno.land/p/nt/uassert/v0"

	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

const (
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

	maxSqrtPriceLimitX96 string = "1461373636630004318706518188784493106690254656249"
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	fooToken = common.GetToken(fooPath)
	barToken = common.GetToken(barPath)
	bazToken = common.GetToken(bazPath)
)

var (
	adminAddr, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	devOpsAddr, _ = access.GetAddress(prabc.ROLE_DEVOPS.String())

	govAddr, _      = access.GetAddress(prabc.ROLE_GOVERNANCE.String())
	stakerAddr, _   = access.GetAddress(prabc.ROLE_STAKER.String())
	emissionAddr, _ = access.GetAddress(prabc.ROLE_EMISSION.String())

	alice      = testutils.TestAddress("alice")
	adminRealm = testing.NewUserRealm(adminAddr)

	poolPath        = "gno.land/r/gnoswap/pool"
	positionPath    = "gno.land/r/gnoswap/position"
	routerPath      = "gno.land/r/gnoswap/router"
	protocolFeePath = "gno.land/r/gnoswap/protocol_fee"

	poolAddr        = chain.PackageAddress(poolPath)
	positionAddr    = chain.PackageAddress(positionPath)
	routerAddr      = chain.PackageAddress(routerPath)
	protocolFeeAddr = chain.PackageAddress(protocolFeePath)

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	rouRealm    = testing.NewCodeRealm(routerPath)
	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	addrUsedInTest = []address{addr01, addr02}

	mockInstance        *poolV1
	registeredTestStore = false
	initializedPool     = false
)

const (
	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

func TokenFaucet(cur realm, t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	testing.SetRealm(adminRealm)
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

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
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

func MintPosition(cur realm, t *testing.T,
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
) (string, string) {
	t.Helper()
	testing.SetRealm(posRealm)

	return pl.Mint(
		cross(cur),
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		caller,
	)
}

// InitialisePoolTest sets up a basic pool environment using GRC20 tokens (bar/baz).
func InitialisePoolTest(cur realm, t *testing.T) {
	t.Helper()

	testing.SetOriginCaller(adminAddr)
	testing.SetRealm(adminRealm)
	// Approve GNS for pool creation fee payment
	TokenApprove(cur, t, gnsPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(cur, t, barPath, adminAddr, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, adminAddr, poolAddr, maxApprove)
	poolPath := GetPoolPath(barPath, bazPath, fee3000)
	if !getMockInstance().ExistsPoolPath(poolPath) {
		mockInstanceCreatePool(0, cur, barPath, bazPath, fee3000, "79228162514264337593543950336")
	}

	// 2. create position
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewUserRealm(alice))
	TokenFaucet(cur, t, barPath, alice)
	TokenFaucet(cur, t, bazPath, alice)
	TokenApprove(cur, t, barPath, alice, poolAddr, 1000)
	TokenApprove(cur, t, bazPath, alice, poolAddr, 1000)
	MintPosition(
		cur,
		t,
		barPath,
		bazPath,
		fee3000,
		int32(1020),
		int32(5040),
		"1000",
		"1000",
		"0",
		"0",
		max_timeout,
		alice,
		alice,
	)
}

// MintPositionAll creates multiple positions across tick ranges using bar/baz tokens.
func MintPositionAll(cur realm, t *testing.T, caller address) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(caller))
	TokenApprove(cur, t, barPath, caller, poolAddr, maxApprove)
	TokenApprove(cur, t, barPath, caller, routerAddr, maxApprove)
	TokenApprove(cur, t, bazPath, caller, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, caller, routerAddr, maxApprove)

	params := []struct {
		tickLower int32
		tickUpper int32
		liquidity uint64
		zeroToOne bool
	}{
		{-300, -240, 10, true},
		{-240, -180, 10, true},
		{-180, -120, 10, true},
		{-120, -60, 10, true},
		{-60, 0, 10, true},
		{0, 60, 10, false},
		{60, 120, 10, false},
		{120, 180, 10, false},
		{180, 240, 10, false},
		{240, 300, 10, false},
		{-360, -300, 10, true},
		{-420, -360, 10, true},
		{-480, -420, 10, true},
		{-540, -480, 10, true},
		{-600, -540, 10, true},
		{300, 360, 10, false},
		{360, 420, 10, false},
		{420, 480, 10, false},
		{480, 540, 10, false},
		{540, 600, 10, false},
	}

	for _, p := range params {
		MintPosition(cur, t,
			barPath,
			bazPath,
			fee3000,
			p.tickLower,
			p.tickUpper,
			"100000000",
			"100000000",
			"0",
			"0",
			max_timeout,
			caller,
			caller)
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

// resetObject resets the object state(clear or make it default values)
func resetObject(cur realm, t *testing.T) {
	initPoolTest(cur, t)
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

func TestBurnTokens(cur realm, t *testing.T) {
	burnTokens(cur, t)

	uassert.Equal(t, foo.BalanceOf(addr01), int64(0)) // 100_000_000 -> 0
	uassert.Equal(t, bar.BalanceOf(addr01), int64(0)) // 100_000_000 -> 0
}

func mockSwapCallback(cur realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross(cur), token1Path, poolAddr, amount1Delta)
	}

	return nil
}

func initPoolTest(cur realm, t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true
		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pl.RegisterInitializer(cross(cur), func(_ int, rlm realm, s pl.IPoolStore) pl.IPool {
			mockInstance = &poolV1{
				store: mock.NewMockPoolStore(),
			}
			return mockInstance
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.UpgradeImpl(cross(cur), mockPoolPath)
}

type mockSlot0 struct {
	sqrtPriceX96 *u256.Uint
	tick         int32
	feeProtocol  uint8
	unlocked     bool
}

type mockBalances struct {
	token0 int64
	token1 int64
}

type createMockPoolParams struct {
	token0Path           string
	token1Path           string
	fee                  uint32
	tickSpacing          int32
	slot0                mockSlot0
	balances             mockBalances
	protocolFees         mockBalances
	feeGrowthGlobal0X128 *u256.Uint
	feeGrowthGlobal1X128 *u256.Uint
	liquidity            *u256.Uint
	ticks                *bptree.BPTree
	tickBitmaps          map[int16]string
	positions            *bptree.BPTree
	observationState     *pl.ObservationState
}

func makeMockPool(params createMockPoolParams) *pl.Pool {
	// NewSlot0/NewPool clone the sqrt price, so a nil value would panic.
	// Default to the 1:1 price when callers don't specify one.
	if params.slot0.sqrtPriceX96 == nil {
		params.slot0.sqrtPriceX96 = u256.MustFromDecimal(EQUAL_PRICE_RATIO)
	}

	slot0 := pl.NewSlot0(
		params.slot0.sqrtPriceX96,
		params.slot0.tick,
		params.slot0.feeProtocol,
		params.slot0.unlocked,
	)

	balances := pl.NewTokenPair()
	balances.SetToken0(params.balances.token0)
	balances.SetToken1(params.balances.token1)

	protocolFees := pl.NewTokenPair()
	protocolFees.SetToken0(params.protocolFees.token0)
	protocolFees.SetToken1(params.protocolFees.token1)

	if params.tickBitmaps == nil {
		params.tickBitmaps = make(map[int16]string)
	}

	pool := pl.NewPool(
		params.token0Path,
		params.token1Path,
		params.fee,
		params.slot0.sqrtPriceX96,
		params.tickSpacing,
		params.slot0.tick,
		params.slot0.feeProtocol,
	)
	pool.SetToken0Path(params.token0Path)
	pool.SetToken1Path(params.token1Path)
	pool.SetFee(params.fee)
	pool.SetTickSpacing(params.tickSpacing)
	pool.SetSlot0(slot0)
	pool.SetBalances(balances)
	pool.SetProtocolFees(protocolFees)
	if params.feeGrowthGlobal0X128 != nil {
		pool.SetFeeGrowthGlobal0X128(params.feeGrowthGlobal0X128)
	}
	if params.feeGrowthGlobal1X128 != nil {
		pool.SetFeeGrowthGlobal1X128(params.feeGrowthGlobal1X128)
	}
	if params.liquidity != nil {
		pool.SetLiquidity(params.liquidity)
	}
	if params.ticks != nil {
		pool.SetTicks(params.ticks)
	}
	pool.SetTickBitmaps(params.tickBitmaps)
	if params.positions != nil {
		pool.SetPositions(params.positions)
	}
	if params.observationState != nil {
		pool.SetObservationState(params.observationState)
	}

	return pool
}

func getMockInstance() *poolV1 {
	if mockInstance == nil {
		mockInstance = &poolV1{
			store: mock.NewMockPoolStore(),
		}
	}

	return mockInstance
}

const currentPoolPath = "gno.land/r/gnoswap/pool"

// mockInstance* helpers are crossing functions that impersonate the pool
// code realm. Each one re-points the current frame to the pool code realm
// via SetRealm, then forwards `cross(cur)` (or the threaded `cur`) into the
// proxy's IPool method as the second argument.

func mockInstanceSetPoolCreationFee(_ int, rlm realm, fee int64) {
	pl.SetPoolCreationFee(cross(rlm), fee)
}

func mockInstanceCreatePool(_ int, rlm realm, token0Path string, token1Path string, fee uint32, sqrtPrice string) {
	pl.CreatePool(cross(rlm), token0Path, token1Path, fee, sqrtPrice)
}

func mockInstanceIncreaseObservationCardinalityNext(_ int, rlm realm, token0Path string, token1Path string, fee uint32, newCardinalityNext uint16) {
	pl.IncreaseObservationCardinalityNext(cross(rlm), token0Path, token1Path, fee, newCardinalityNext)
}

func mockInstanceSetTickCrossHook(_ int, rlm realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	pl.SetTickCrossHook(cross(rlm), hook)
}

func mockInstanceSetSwapStartHook(_ int, rlm realm, hook func(cur realm, poolPath string, timestamp int64)) {
	pl.SetSwapStartHook(cross(rlm), hook)
}

func mockInstanceSetSwapEndHook(_ int, rlm realm, hook func(cur realm, poolPath string) error) {
	pl.SetSwapEndHook(cross(rlm), hook)
}

func mockInstanceMint(_ int, rlm realm, token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	return pl.Mint(cross(rlm), token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func mockInstanceMint2(cur realm, token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	return pl.Mint(cross(cur), token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func mockInstanceBurn(_ int, rlm realm, token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	return pl.Burn(cross(rlm), token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func mockInstanceCollect(_ int, rlm realm, token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string) {
	return pl.Collect(cross(rlm), token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func mockInstanceCollectProtocol(_ int, rlm realm, token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string) {
	return pl.CollectProtocol(cross(rlm), token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
}

func mockInstanceSwap(_ int, rlm realm, token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(cur realm, amount0Delta int64, amount1Delta int64, _ *pl.CallbackMarker) error) (string, string) {
	return pl.Swap(cross(rlm), token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, payer, swapCallback)
}

func mockInstanceHandleWithdrawalFee(_ int, rlm realm, token0Path string, amount0 string, token1Path string, amount1 string, positionCaller address) (string, string, string, string) {
	return pl.HandleWithdrawalFee(cross(rlm), token0Path, amount0, token1Path, amount1, positionCaller)
}

func mockInstanceSetWithdrawalFee(_ int, rlm realm, fee uint64) {
	pl.SetWithdrawalFee(cross(rlm), fee)
}

func mockInstanceSetFeeProtocol(_ int, rlm realm, feeProtocol0 uint8, feeProtocol1 uint8) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pl.SetFeeProtocol(cross(rlm), feeProtocol0, feeProtocol1)
}
