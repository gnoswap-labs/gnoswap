package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	ugnotDenom string = "ugnot"
	ugnotPath  string = "gno.land/r/gnoswap/v1/pool:ugnot"
	wugnotPath string = "gno.land/r/demo/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/v1/gns"
	barPath    string = "gno.land/r/onbloc/bar"
	bazPath    string = "gno.land/r/onbloc/baz"
	fooPath    string = "gno.land/r/onbloc/foo"
	oblPath    string = "gno.land/r/onbloc/obl"
	quxPath    string = "gno.land/r/onbloc/qux"

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	maxApprove  uint64 = 18446744073709551615
	max_timeout int64  = 9999999999
)

const (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminAddr   = consts.ADMIN
	admin       = pusers.AddressOrName(consts.ADMIN)
	alice       = pusers.AddressOrName(testutils.TestAddress("alice"))
	pool        = pusers.AddressOrName(consts.POOL_ADDR)
	protocolFee = pusers.AddressOrName(consts.PROTOCOL_FEE_ADDR)
	adminRealm  = std.NewUserRealm(users.Resolve(admin))
	posRealm    = std.NewCodeRealm(consts.POSITION_PATH)

	// addresses used in tests
	addrUsedInTest = []std.Address{addr01, addr02}
)

func CreatePool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller std.Address,
) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(token0, token1, fee, sqrtPriceX96)
		//SetPoolTierByAdmin(poolPath, TIER_1)
	}
}

func LPTokenStake(t *testing.T, owner pusers.AddressOrName, tokenId uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	//StakeToken(tokenId)
}

func LPTokenUnStake(t *testing.T, owner pusers.AddressOrName, tokenId uint64, unwrap bool) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	//UnstakeToken(tokenId, unwrap)
}

func InitialisePoolTest(t *testing.T) {
	t.Helper()

	ugnotFaucet(t, users.Resolve(admin), 100_000_000_000_000)
	ugnotDeposit(t, users.Resolve(admin), 100_000_000_000_000)
	TokenFaucet(t, gnsPath, admin)

	std.TestSetOrigCaller(users.Resolve(admin))
	TokenApprove(t, gnsPath, admin, pool, maxApprove)
	poolPath := pl.GetPoolPath(wugnotPath, gnsPath, fee3000)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(wugnotPath, gnsPath, fee3000, "79228162514264337593543950336")
	}

	std.TestSetOrigCaller(users.Resolve(alice))
	TokenFaucet(t, wugnotPath, alice)
	TokenFaucet(t, gnsPath, alice)
	TokenApprove(t, wugnotPath, alice, pool, uint64(1000))
	TokenApprove(t, gnsPath, alice, pool, uint64(1000))
	MintPosition(t,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(1020),
		int32(5040),
		"1000",
		"1000",
		"0",
		"0",
		max_timeout,
		users.Resolve(alice),
		users.Resolve(alice),
	)
}

func CreateSecondPoolWithoutFee(t *testing.T) {
	std.TestSetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(0)

	CreatePool(t,
		barPath,
		bazPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		users.Resolve(admin),
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	std.TestSetRealm(adminRealm)

	TokenApprove(t, barPath, admin, pool, consts.UINT64_MAX)
	TokenApprove(t, bazPath, admin, pool, consts.UINT64_MAX)

	// mint position
	return pn.Mint(
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
		users.Resolve(admin),
		users.Resolve(admin),
	)
}

func TokenFaucet(t *testing.T, tokenPath string, to pusers.AddressOrName) {
	t.Helper()
	std.TestSetOrigCaller(users.Resolve(admin))
	defaultAmount := uint64(5_000_000_000)

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

func TokenBalance(t *testing.T, tokenPath string, owner pusers.AddressOrName) uint64 {
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

func TokenAllowance(t *testing.T, tokenPath string, owner, spender pusers.AddressOrName) uint64 {
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

func TokenApprove(t *testing.T, tokenPath string, owner, spender pusers.AddressOrName, amount uint64) {
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
	mintTo std.Address,
	caller std.Address,
) (uint64, string, string, string) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(caller))

	return pn.Mint(
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
		caller)
}

func wugnotApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	wugnot.Approve(spender, amount)
}

func gnsApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	gns.Approve(spender, amount)
}

func barApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	bar.Approve(spender, amount)
}

func bazApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	baz.Approve(spender, amount)
}

func fooApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	foo.Approve(spender, amount)
}

func oblApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	obl.Approve(spender, amount)
}

func quxApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	qux.Approve(spender, amount)
}

func wugnotTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	wugnot.Transfer(to, amount)
}

func gnsTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	gns.Transfer(to, amount)
}

func barTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	bar.Transfer(to, amount)
}

func bazTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	baz.Transfer(to, amount)
}

func fooTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	foo.Transfer(to, amount)
}

func oblTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	obl.Transfer(to, amount)
}

func quxTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	qux.Transfer(to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to std.Address, amount uint64) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(from))
	std.TestSetOrigSend(std.Coins{{ugnotDenom, int64(amount)}}, nil)
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(from, to, std.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr std.Address) uint64 {
	t.Helper()

	banker := std.GetBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf(ugnotDenom))
}

func ugnotMint(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.IssueCoin(addr, denom, amount)
	std.TestIssueCoins(addr, std.Coins{{denom, int64(amount)}})
}

func ugnotBurn(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	faucetAddress := users.Resolve(admin)
	std.TestSetOrigCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := std.Coins{{ugnotDenom, int64(amount)}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		std.TestSetOrigSend(newCoins, nil)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func ugnotDeposit(t *testing.T, addr std.Address, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(addr))
	wugnotAddr := consts.WUGNOT_ADDR
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(addr, wugnotAddr, std.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit()
}

// burnAllNFT burns all NFTs
func burnAllNFT(t *testing.T) {
	t.Helper()

	std.TestSetRealm(std.NewCodeRealm(consts.POSITION_PATH))
	for i := uint64(1); i <= gnft.TotalSupply(); i++ {
		gnft.Burn(tid(i))
	}
}

func deletePoolTier(t *testing.T, poolPath string) {
	t.Helper()
	if poolTier != nil {
		poolTier.changeTier(uint64(std.GetHeight()), poolPath, 0)
	}
}

func addPoolTier(t *testing.T, poolPath string, tier uint64) {
	t.Helper()
	if poolTier != nil {
		poolTier.changeTier(uint64(std.GetHeight()), poolPath, tier)
		if pools != nil {
			pools.GetOrCreate(poolPath)
		}
	}
}

func changeWarmup(t *testing.T, index int, blockDuration int64) {
	modifyWarmup(index, blockDuration)
}

func getNumPoolTiers(t *testing.T) (uint64, uint64, uint64) {
	tier1Num := poolTier.count[1].tree.Size()
	tier2Num := poolTier.count[2].tree.Size()
	tier3Num := poolTier.count[3].tree.Size()

	return uint64(tier1Num), uint64(tier2Num), uint64(tier3Num)
}

type gnsBalanceTracker struct {
	height               uint64
	stakerBalance        uint64
	devOpsBalance        uint64
	communityPoolBalance uint64
	govStakerBalance     uint64
	protocolFeeBalance   uint64
	callerBalance        uint64
}

func gnsBalanceCheck(t *testing.T, beforeBalance gnsBalanceTracker, printChange bool) gnsBalanceTracker {
	t.Helper()

	caller := std.PrevRealm().Addr()
	height := uint64(std.GetHeight())
	stakerBalance := gns.BalanceOf(a2u(consts.STAKER_ADDR))
	devOpsBalance := gns.BalanceOf(a2u(consts.DEV_OPS))
	communityPoolBalance := gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))
	govStakerBalance := gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
	protocolFeeBalance := gns.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR))
	callerBalance := gns.BalanceOf(a2u(caller))

	if printChange {
		println("[START] gnsBalanceCheck")
		println("height", beforeBalance.height, "->", height, "|| diff", height-beforeBalance.height)
		println("stakerBalance", beforeBalance.stakerBalance, "->", stakerBalance, "|| diff", stakerBalance-beforeBalance.stakerBalance)
		println("devOpsBalance", beforeBalance.devOpsBalance, "->", devOpsBalance, "|| diff", devOpsBalance-beforeBalance.devOpsBalance)
		println("communityPoolBalance", beforeBalance.communityPoolBalance, "->", communityPoolBalance, "|| diff", communityPoolBalance-beforeBalance.communityPoolBalance)
		println("govStakerBalance", beforeBalance.govStakerBalance, "->", govStakerBalance, "|| diff", govStakerBalance-beforeBalance.govStakerBalance)
		println("protocolFeeBalance", beforeBalance.protocolFeeBalance, "->", protocolFeeBalance, "|| diff", protocolFeeBalance-beforeBalance.protocolFeeBalance)
		println("callerBalance", beforeBalance.callerBalance, "->", callerBalance, "|| diff", callerBalance-beforeBalance.callerBalance)
		println("[END] gnsBalanceCheck")
		println()
	}

	return gnsBalanceTracker{
		height:               height,
		stakerBalance:        stakerBalance,
		devOpsBalance:        devOpsBalance,
		communityPoolBalance: communityPoolBalance,
		govStakerBalance:     govStakerBalance,
		protocolFeeBalance:   protocolFeeBalance,
		callerBalance:        callerBalance,
	}
}

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected uint64, actual uint64) bool {
	lowerBound := expected * 999999 / 1000000
	upperBound := expected * 1000001 / 1000000
	return actual >= lowerBound && actual <= upperBound
}

func getPrintInfo(t *testing.T) string {
	en.MintAndDistributeGns()

	emissionDebug := ApiEmissionDebugInfo{}
	emissionDebug.Height = std.GetHeight()
	emissionDebug.Time = time.Now().Unix()
	emissionDebug.GnsStaker = gns.BalanceOf(a2u(consts.STAKER_ADDR))
	emissionDebug.GnsDevOps = gns.BalanceOf(a2u(consts.DEV_OPS))
	emissionDebug.GnsCommunityPool = gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))
	emissionDebug.GnsGovStaker = gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
	emissionDebug.GnsProtocolFee = gns.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR))
	emissionDebug.GnsADMIN = gns.BalanceOf(a2u(consts.ADMIN))

	poolTiers := make(map[string]uint64)
	pools.tree.Iterate("", "", func(poolPath string, iPool interface{}) bool {
		poolTier := poolTier.CurrentTier(poolPath, uint64(std.GetHeight()))
		poolTiers[poolPath] = poolTier
		return false
	})

	for poolPath, poolTier := range poolTiers {
		pool := ApiEmissionDebugPool{}
		pool.PoolPath = poolPath
		pool.Tier = poolTier

		numTier1, numTier2, numTier3 := getNumPoolTiers(t)
		if poolTier == 1 {
			pool.NumPoolInSameTier = numTier1
		} else if poolTier == 2 {
			pool.NumPoolInSameTier = numTier2
		} else if poolTier == 3 {
			pool.NumPoolInSameTier = numTier3
		}

		deposits.tree.Iterate("", "", func(tokenIdStr string, value interface{}) bool {
			tokenId := DecodeUint(tokenIdStr)
			deposit := value.(*Deposit)

			if deposit.targetPoolPath == poolPath {
				position := ApiEmissionDebugPosition{}
				position.LpTokenId = tokenId
				position.StakedHeight = deposit.stakeHeight
				position.StakedTimestamp = deposit.stakeTimestamp
				position.StakedDuration = emissionDebug.Height - deposit.stakeHeight

				position.Ratio = getRewardRatio(t, position.StakedDuration)
				pool.Position = append(pool.Position, position)
			}
			return false
		})
		emissionDebug.Pool = append(emissionDebug.Pool, pool)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"height": json.StringNode("", ufmt.Sprintf("%d", emissionDebug.Height)),
		"time":   json.StringNode("", ufmt.Sprintf("%d", emissionDebug.Time)),
		"gns": json.ObjectNode("", map[string]*json.Node{
			"staker":        json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsStaker)),
			"devOps":        json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsDevOps)),
			"communityPool": json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsCommunityPool)),
			"govStaker":     json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsGovStaker)),
			"protocolFee":   json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsProtocolFee)),
			"GnoswapAdmin":  json.StringNode("", ufmt.Sprintf("%d", emissionDebug.GnsADMIN)),
		}),
		"pool": json.ArrayNode("", makePoolsNode(t, emissionDebug.Pool)),
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic("JSON MARSHAL ERROR")
	}

	return string(b)
}

type ApiEmissionDebugInfo struct {
	Height           int64                  `json:"height"`
	Time             int64                  `json:"time"`
	GnsStaker        uint64                 `json:"gnsStaker"`
	GnsDevOps        uint64                 `json:"gnsDevOps"`
	GnsCommunityPool uint64                 `json:"gnsCommunityPool"`
	GnsGovStaker     uint64                 `json:"gnsGovStaker"`
	GnsProtocolFee   uint64                 `json:"gnsProtocolFee"`
	GnsADMIN         uint64                 `json:"gnsADMIN"`
	Pool             []ApiEmissionDebugPool `json:"pool"`
}

type ApiEmissionDebugPool struct {
	PoolPath          string                     `json:"poolPath"`
	Tier              uint64                     `json:"tier"`
	NumPoolInSameTier uint64                     `json:"numPoolInSameTier"`
	PoolReward        uint64                     `json:"poolReward"`
	Position          []ApiEmissionDebugPosition `json:"position"`
}

type ApiEmissionDebugPosition struct {
	LpTokenId       uint64 `json:"lpTokenId"`
	StakedHeight    int64  `json:"stakedHeight"`
	StakedTimestamp int64  `json:"stakedTimestamp"`
	StakedDuration  int64  `json:"stakedDuration"`
	FullAmount      uint64 `json:"fullAmount"`
	Ratio           uint64 `json:"ratio"`
	RatioAmount     uint64 `json:"ratioAmount"`
}

func getRewardRatio(t *testing.T, height int64) uint64 {
	t.Helper()
	warmups := InstantiateWarmup(height)

	for _, warmup := range warmups {
		if height < warmup.NextWarmupHeight {
			return warmup.WarmupRatio
		}
	}

	// passed all warmup-periods
	return 100
}

func makePoolsNode(t *testing.T, emissionPool []ApiEmissionDebugPool) []*json.Node {
	poolNodes := make([]*json.Node, 0)

	poolTiers := make(map[string]uint64)
	pools.tree.Iterate("", "", func(poolPath string, iPool interface{}) bool {
		poolTier := poolTier.CurrentTier(poolPath, uint64(std.GetHeight()))
		poolTiers[poolPath] = poolTier
		return false
	})

	for poolPath, poolTier := range poolTiers {
		numTier1, numTier2, numTier3 := getNumPoolTiers(t)
		numPoolSameTier := uint64(0)
		tier := poolTier
		if tier == 1 {
			numPoolSameTier = numTier1
		} else if tier == 2 {
			numPoolSameTier = numTier2
		} else if tier == 3 {
			numPoolSameTier = numTier3
		}

		poolNodes = append(poolNodes, json.ObjectNode("", map[string]*json.Node{
			"poolPath":        json.StringNode("poolPath", poolPath),
			"tier":            json.StringNode("tier", ufmt.Sprintf("%d", tier)),
			"numPoolSameTier": json.StringNode("numPoolSameTier", ufmt.Sprintf("%d", numPoolSameTier)),
			"position":        json.ArrayNode("", makePositionsNode(t, poolPath)),
		}))
	}

	return poolNodes
}

func makePositionsNode(t *testing.T, poolPath string) []*json.Node {
	positions := make([]*json.Node, 0)

	deposits.tree.Iterate("", "", func(tokenIdStr string, value interface{}) bool {
		tokenId := DecodeUint(tokenIdStr)
		deposit := value.(*Deposit)

		if deposit.targetPoolPath == poolPath {
			stakedDuration := std.GetHeight() - deposit.stakeHeight
			ratio := getRewardRatio(t, stakedDuration)

			rewardByWarmup := calcPositionRewardByWarmups(uint64(std.GetHeight()), uint64(tokenId))
			if len(rewardByWarmup) != 4 {
				panic("len(rewardByWarmup) != 4")
			}

			reward30 := rewardByWarmup[0].Internal
			penalty30 := rewardByWarmup[0].InternalPenalty
			full30 := reward30 + penalty30

			reward50 := rewardByWarmup[1].Internal
			penalty50 := rewardByWarmup[1].InternalPenalty
			full50 := reward50 + penalty50

			reward70 := rewardByWarmup[2].Internal
			penalty70 := rewardByWarmup[2].InternalPenalty
			full70 := reward70 + penalty70

			reward100 := rewardByWarmup[3].Internal
			penalty100 := rewardByWarmup[3].InternalPenalty
			full100 := reward100 + penalty100

			fullAmount := full30 + full50 + full70 + full100
			warmUpAmount := reward30 + reward50 + reward70 + reward100

			positions = append(positions, json.ObjectNode("", map[string]*json.Node{
				"lpTokenId":       json.StringNode("lpTokenId", ufmt.Sprintf("%d", tokenId)),
				"stakedHeight":    json.StringNode("stakedHeight", ufmt.Sprintf("%d", deposit.stakeHeight)),
				"stakedTimestamp": json.StringNode("stakedTimestamp", ufmt.Sprintf("%d", deposit.stakeTimestamp)),
				"stakedDuration":  json.StringNode("stakedDuration", ufmt.Sprintf("%d", stakedDuration)),
				"fullAmount":      json.StringNode("fullAmount", ufmt.Sprintf("%d", fullAmount)),
				"ratio":           json.StringNode("ratio", ufmt.Sprintf("%d", ratio)),
				"warmUpAmount":    json.StringNode("warmUpAmount", ufmt.Sprintf("%d", warmUpAmount)),
				"full30":          json.StringNode("full30", ufmt.Sprintf("%d", full30)),
				"give30":          json.StringNode("give30", ufmt.Sprintf("%d", reward30)),
				"penalty30":       json.StringNode("penalty30", ufmt.Sprintf("%d", penalty30)),
				"full50":          json.StringNode("full50", ufmt.Sprintf("%d", full50)),
				"give50":          json.StringNode("give50", ufmt.Sprintf("%d", reward50)),
				"penalty50":       json.StringNode("penalty50", ufmt.Sprintf("%d", penalty50)),
				"full70":          json.StringNode("full70", ufmt.Sprintf("%d", full70)),
				"give70":          json.StringNode("give70", ufmt.Sprintf("%d", reward70)),
				"penalty70":       json.StringNode("penalty70", ufmt.Sprintf("%d", penalty70)),
				"full100":         json.StringNode("full100", ufmt.Sprintf("%d", full100)),
				"give100":         json.StringNode("give100", ufmt.Sprintf("%d", reward100)),
				"penalty100":      json.StringNode("penalty100", ufmt.Sprintf("%d", penalty100)),
			}))
		}

		return false
	})

	return positions
}
