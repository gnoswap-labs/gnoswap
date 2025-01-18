package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	rr "gno.land/r/gnoswap/v1/router"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/demo/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
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

var (
	wugnotAddr = consts.WUGNOT_ADDR
	stakerAddr = consts.STAKER_ADDR
	anoAdmin   = users.Resolve(admin)
)

func TestFullInternalExternal(t *testing.T) {
	testInit(t)
	testCreatePoolWugnotGns3000Tier01(t)
	testCreateExternalIncentiveGns(t) // GNS로 리워드 생성 ( gnot:gns:0.3% 풀은 인터널도 GNS고 익스터널도 GNS )
	testMintPos01InRange(t)

	testCreateBarBaz500Tier02(t) // 포지션 아예 없어서 커뮤니티 풀로 빠져야 함
	testMintPos02InRange(t)
	testMintPos03OutRange(t)
	testMintPos04OutRange(t)
	testMintPos05OutRange(t)
	testMintPos06OutRange(t)

	testStakeToken01(t) // 여기 직전까지는 스테이킹 된 포지션 없어서 wugnot gns 0.3% 풀에 쌓인 리워드 커뮤니티 풀로 빠져야 함
	testStakeToken02(t) //
	testStakeToken03(t) //
	testStakeToken04(t) //
	testStakeToken05(t) //
	testStakeToken06(t) //

	testCollectRewardAll_30(t)  // 10블록 쯤 증가시키고, 한 블록 내에서 1~6번 포지션 리워드 수령 (웜업 30% 구간)
	testCollectRewardAll_50(t)  // 웜업 50% 까지 증가시키고, 한 블록 내에서 1~6번 포지션 리워드 수령
	testCollectRewardAll_70(t)  // 웜업 70% 까지 증가시키고, 한 블록 내에서 1~6번 포지션 리워드 수령
	testCollectRewardAll_100(t) // 웜업 100% 까지 증가시키고, 한 블록 내에서 1~6번 포지션 리워드 수령
	//
	//testSwap(t) // xx, 스왑 여러번 하도록 더 추가
	//
	//testCreatePoolBarFoo100Tier03(t)    // xx, 틱 600000
	//testCollectRewardDummy(t)           // xx, 2번 포지션 리워드 수령 => 그러면 bar foo 풀에는 스테이킹 된거 없어서 커뮤 풀로 빠져야 함
	//testOneClickStakingPos07OutRange(t) // xx, 원클릭 스테이킹으로 애초에 outRange => 몇 블록 증가 후 7번 포지션 리워드 수령 해보면 outRange기 떄문에 커뮤 풀로 빠져야 함
	//
	////testChangeAvgBlockTimeTo4000(t) // XXXXXXXXX 평균 블록 시간 변경
	//testChangeDistributionPctByAdmin(t) // 스테이커한테 가는 에미션 비율 변경
	//testUnstakeToken01(t)               // 전체 스티이킹 된 유도성 변경
	//
	//testCreatePoolBazQuxExternalOnly(t) // xx, 풀 만드는데 익스터널 인센티브만 있는 풀임
	//testCreateExternalIncentiveBar(t)   // xx, 위에서 만든 풀 대상으로 익스터널 인센티브 생성
	//testMintPos08InRange(t)             // xx, 포지션 생성
	//testStakeToken08(t)                 // xx, 스테이킹
	//testCollectReward08(t)              // xx, 10 블록 쯤 증가시키고 리워드 수령하면 0으로 나와야 함 (익스터널 아직 시작 안 됨)
	//testStartExternalIncentive(t)       // xx, 익스터널 인센티브 시작시키고 (블록 스킵 충분히)
	//testCollectReward08AfterStart(t)    // xx, 10 블록 증가 후 리워드 수령하면 웜업 구간에 맞는 10 블록 만큼의 리워드 나와야 함 ( 몇 퍼센트 구간인지는 위에서 익스터널 시작시킬려고 몇 블록을 스킵했는지에 따라 다름)
	//
	//testEndExternalIncentiveBar(t) // bar 인센티브 종료 ( 페널티 수량 환불되야 함 )
	//
	//testReStakeTokenPos01(t) // 스테이킹 해서 웝업 100% 찍었다가 언스테이킹 된 토큰 다시 스테이킹 ( 웜업 처음(30%)부터 적용되야 함 )

}

func testInit(t *testing.T) {
	t.Run("initialize", func(t *testing.T) {
		println("[", std.GetHeight(), "] [testInit]")
		std.TestSetRealm(adminRealm)

		// 언스테이킹 수수료 0으로 바꿈 // 계산 편함
		SetUnstakingFeeByAdmin(0)
		println("[", std.GetHeight(), "] [testInit] SetUnstakingFeeByAdmin(0)")

		// 에미션 분배 커뮤니티 비율 0%로 (대신 devOps 한테 많이 가게))
		// 에미션 기본 분배 대상 4개 중에 커뮤니티 풀한테 주는 비율이 이미 있어서 인터널 페널티 발생 시 잔액에 영향을 주기 때문에 애초에 커뮤니티 풀한테는 자동으로 안 풀리게 하도 테스트하는게 깔끔
		en.ChangeDistributionPctByAdmin(
			1, 7500, // 스테이커
			2, 2500, // 데브옵스
			3, 0, // 커뮤니티풀
			4, 0, // xGNS
		)
		println("[", std.GetHeight(), "] [testInit] ChangeDistributionPctByAdmin(75, 25, 0, 0)")

		// admin 계정한테 wugnot 토큰 미리 좀 넉넉하게 할당
		std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
		std.TestSetOrigSend(std.Coins{{"ugnot", 50_000_000_000_000}}, nil)
		wugnot.Deposit()
		std.TestSetOrigSend(nil, nil)
		uassert.Equal(t, uint64(50_000_000_000_000), wugnot.BalanceOf(pusers.AddressOrName(adminAddr)))
		uassert.Equal(t, "50000000000000ugnot", (banker.GetCoins(adminAddr).String()))
	})
}

func testCreatePoolWugnotGns3000Tier01(t *testing.T) {
	t.Run("create pool gnot:gns:0.3%", func(t *testing.T) {
		println("[", std.GetHeight(), "] [create pool gnot:gns:0.3%]")
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		pl.CreatePool(wugnotPath, gnsPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString()) // current tick 0
		println("[", std.GetHeight(), "] Already Set PoolTier 1")

		oneBlockEmissionAmount := uint64(14269406)
		oneBlockStakerAmount := uint64(10702054)
		oneBlockDevOpsAmount := uint64(3567351)

		uassert.Equal(t, uint64(100000000000000), gns.TotalSupply())
		uassert.Equal(t, uint64(0), gnsBalance(consts.EMISSION_ADDR))
		uassert.Equal(t, uint64(0), gnsBalance(consts.STAKER_ADDR))
		uassert.Equal(t, uint64(0), gnsBalance(consts.DEV_OPS))
		std.TestSkipHeights(3)
	})
}

func testCreateExternalIncentiveGns(t *testing.T) {
	t.Run("create external incentive gns for gnot:gns:0.3% pool", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [create external incentive gns for gnot:gns:0.3% pool]")
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.STAKER_ADDR), consts.UINT64_MAX) // this includes depositGnsAmount
		CreateExternalIncentive(
			"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000",
			consts.GNS_PATH,
			20000000,
			1234569600,                  // 855
			1234569600+TIMESTAMP_90DAYS, // 855 + 3888000 = 3893855
		)
		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance, gnsBalance(consts.STAKER_ADDR))
		uassert.Equal(t, uint64(0)+initialDepOpsAmount, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos01InRange(t *testing.T) {
	t.Run("mint position 01 in range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 01 in range]")
		std.TestSetRealm(adminRealm)

		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			wugnotPath,
			gnsPath,
			fee3000,
			int32(-60),
			int32(60),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+gnsPer2Block, gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testCreateBarBaz500Tier02(t *testing.T) {
	t.Run("create bar:baz:500 pool, and set internal emission tier #2", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [create bar:baz:500 pool, and set internal emission tier #2]")
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		pl.CreatePool(barPath, bazPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		SetPoolTierByAdmin("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", 2)
		println("[", std.GetHeight(), "] (gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500) Set PoolTier 2")

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos02InRange(t *testing.T) {
	t.Run("mint position 02 in range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 02 in range]")
		std.TestSetRealm(adminRealm)

		bar.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		baz.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			barPath,
			bazPath,
			fee500,
			int32(-60),
			int32(60),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos03OutRange(t *testing.T) {
	t.Run("mint position 03 out range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 03 out range]")
		std.TestSetRealm(adminRealm)

		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			wugnotPath,
			gnsPath,
			fee3000,
			int32(60),
			int32(120),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos04OutRange(t *testing.T) {
	t.Run("mint position 04 out range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 04 out range]")
		std.TestSetRealm(adminRealm)

		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			barPath,
			bazPath,
			fee500,
			int32(60),
			int32(120),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos05OutRange(t *testing.T) {
	t.Run("mint position 05 out range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 05 out range]")
		std.TestSetRealm(adminRealm)

		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			wugnotPath,
			gnsPath,
			fee3000,
			int32(-120),
			int32(-60),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testMintPos06OutRange(t *testing.T) {
	t.Run("mint position 06 out range", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [mint position 06 out range]")
		std.TestSetRealm(adminRealm)

		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		pn.Mint(
			barPath,
			bazPath,
			fee500,
			int32(-120),
			int32(-60),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken01(t *testing.T) {
	t.Run("stake token 01", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward Available ******] [stake token 01]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(1))
		approver, _ := gnft.GetApproved(common.TokenIdFrom(1))
		println("approver", approver)
		StakeToken(1)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken02(t *testing.T) {
	t.Run("stake token 02", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward Available ******] [stake token 02]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(2))
		StakeToken(2)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken03(t *testing.T) {
	t.Run("stake token 03", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward No OutRange ******] [stake token 03]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(3))
		StakeToken(3)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken04(t *testing.T) {
	t.Run("stake token 04", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward No OutRange ******] [stake token 04]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(4))
		StakeToken(4)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken05(t *testing.T) {
	t.Run("stake token 05", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward No OutRange ******] [stake token 05]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(5))
		StakeToken(5)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testStakeToken06(t *testing.T) {
	t.Run("stake token 06", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "][****** Reward No OutRange ******] [stake token 06]")
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(6))
		StakeToken(6)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testCollectRewardAll_30(t *testing.T) {
	t.Run("collect reward for all position, while warm up is in 30", func(t *testing.T) {
		genesisBlockHeight := int64(123)
		currentHeight := std.GetHeight()
		Gap := uint64(currentHeight - genesisBlockHeight)
		println("[", std.GetHeight(), "] [collect reward for all position, while warm up is in 30]")
		std.TestSkipHeights(1)
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)

		oneBlockEmissionAmount := uint64(14269406)
		initialStakerAmount := uint64(32106163) // 14269406*3*0.75
		oneBlockStakerAmount := uint64(10702054)
		initialDepOpsAmount := uint64(10702054) // 14269406*3*0.25
		oneBlockDevOpsAmount := uint64(3567351)
		externalInecntiveDeposit := uint64(20000000) + uint64(1_000_000_000) // reward + depositGns
		emissionLeft := uint64(1)
		gnsPer2Block := uint64(1)

		// uassert.Equal(t, uint64(100000000000000)+(Gap*oneBlockEmissionAmount), gns.TotalSupply())
		// uassert.Equal(t, uint64(0)+emissionLeft, gnsBalance(consts.EMISSION_ADDR))

		// expectStakerBalance := uint64(0) + initialStakerAmount + ((Gap - 3) * oneBlockStakerAmount) + externalInecntiveDeposit
		// uassert.Equal(t, expectStakerBalance+(uint64((currentHeight-126))*gnsPer2Block), gnsBalance(consts.STAKER_ADDR))
		// expectedDevOpsBalance := uint64(0) + initialDepOpsAmount + ((Gap - 3) * oneBlockDevOpsAmount)
		// uassert.Equal(t, expectedDevOpsBalance, gnsBalance(consts.DEV_OPS))

		std.TestSkipHeights(1)
	})
}

func testCollectRewardAll_50(t *testing.T) {
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(gns.GetAvgBlockTimeInMs())
	blocksIn5Days := int64(5 * blocksInDay)
	blocksIn10Days := int64(10 * blocksInDay)
	blocksIn30Days := int64(30 * blocksInDay)

	t.Run("make warm up to 50% (currently reward for 30% and 50% are mixed)", func(t *testing.T) {
		std.TestSkipHeights(blocksIn5Days)
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})

	t.Run("only single block for 50% warm up", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})
}

func testCollectRewardAll_70(t *testing.T) {
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(gns.GetAvgBlockTimeInMs())
	blocksIn5Days := int64(5 * blocksInDay)
	blocksIn10Days := int64(10 * blocksInDay)
	blocksIn30Days := int64(30 * blocksInDay)

	t.Run("make warm up to 70% (currently reward for 50% and 70% are mixed)", func(t *testing.T) {
		std.TestSkipHeights(blocksIn10Days)
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})

	t.Run("only single block for 70% warm up", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})
}

func testCollectRewardAll_100(t *testing.T) {
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(gns.GetAvgBlockTimeInMs())
	blocksIn5Days := int64(5 * blocksInDay)
	blocksIn10Days := int64(10 * blocksInDay)
	blocksIn30Days := int64(30 * blocksInDay)

	t.Run("make warm up to 100% (currently reward for 70% and 100% are mixed)", func(t *testing.T) {
		std.TestSkipHeights(blocksIn30Days)
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})

	t.Run("only single block for 100% warm up", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})
}

func testSwap(t *testing.T) {
	t.Run("swap tokenXX to tokenXX", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		// 1st swap
		wugnot.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)

		wugnot.Approve(common.AddrToUser(consts.ROUTER_ADDR), consts.UINT64_MAX)
		gns.Approve(common.AddrToUser(consts.ROUTER_ADDR), consts.UINT64_MAX)

		tokenIn, tokenOut := rr.ExactInSwapRoute(
			wugnotPath, // inputToken
			gnsPath,    // outputToken
			"10000000", // finalAmountIn
			"gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000", // RouteArr
			"100",       // quoteArr
			"0",         // amountOutMin
			max_timeout, // deadline
		)
		std.TestSkipHeights(1)
	})
}

func testCreatePoolBarFoo100Tier03(t *testing.T) {
	t.Run("create bar:foo:100 pool, and set internal emission tier #3", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		pl.CreatePool(barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(600000).ToString())
		std.TestSkipHeights(1)

		SetPoolTierByAdmin("gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100", 3)
		std.TestSkipHeights(1)
	})
}

func testCollectRewardDummy(t *testing.T) {
	t.Run("collect reward for all position, while warm up is in 30", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		CollectReward(2, false)
		std.TestSkipHeights(1)
	})
}

func testOneClickStakingPos07OutRange(t *testing.T) {
	t.Run("mint and stake grc20 pair", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
		foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

		lpTokenId, liquidity, amount0, amount1, poolPath := MintAndStake(
			barPath,    // token0
			fooPath,    // token1
			fee100,     // fee
			int32(-60), // tickLower
			int32(60),  // tickUpper
			"1000",     // amount0Desired
			"1000",     // amount1Desired
			"0",        // amount0Min
			"0",        // amount1Min
			max_timeout,
		)
		uassert.Equal(t, lpTokenId, uint64(7))

		std.TestSkipHeights(1)
	})
}

func testChangeAvgBlockTimeTo4000(t *testing.T) {
	// 원래 블록 시간 2초였으나 4초로 증가
	// 1 블록 당 민팅되는 GNS 수량 2배로 증가됨
	t.Run("change avg block time to 4000", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		gns.SetAvgBlockTimeInMsByAdmin(4000)
		std.TestSkipHeights(1)
	})

	t.Run("collect reward position 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		CollectReward(1, false) // 1 블록 증가하고 리워드 확인해보면 얘한테 떨어지는 수량 거의 2배로 되야 함
		std.TestSkipHeights(1)

		// 원복
		gns.SetAvgBlockTimeInMsByAdmin(2000)
	})
}

func testChangeDistributionPctByAdmin(t *testing.T) {
	t.Run("change staker's emission distribution pct to 50%", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		en.ChangeDistributionPctByAdmin(
			1, 5000, // 스테이커
			2, 5000, // 데브옵스
			3, 0, // 커뮤니티풀
			4, 0, // xGNS
		)
		std.TestSkipHeights(1)
	})

	t.Run("collect reward position 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		std.TestSkipHeights(1)
		// 에미션을 통해 스테이커한테 분배되는 비율이 감소 됨
		// 따라서 각 포지션이 수령할 수 있는 리워드 수량도 감소되야 함

		// 원복
		en.ChangeDistributionPctByAdmin(
			1, 7500, // 스테이커
			2, 2500, // 데브옵스
			3, 0, // 커뮤니티풀
			4, 0, // xGNS
		)
		std.TestSkipHeights(1)
	})
}

func testUnstakeToken01(t *testing.T) {
	t.Run("unstake token 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		UnstakeToken(1, false)
		std.TestSkipHeights(1)
	})

	t.Run("collect reward for all position", func(t *testing.T) {
		// 포지션 01번 언스테이킹 되었으니
		// 동일한 풀에 있는 나머지 inRange 포지션들의 리워드는 증가되야 함
		std.TestSetRealm(adminRealm)
		CollectReward(2, false)
		CollectReward(3, false)
		CollectReward(4, false)
		CollectReward(5, false)
		CollectReward(6, false)
		std.TestSkipHeights(1)
	})
}

func testCreatePoolBazQuxExternalOnly(t *testing.T) {
	t.Run("create pool baz:qux:0.3%", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		pl.CreatePool(bazPath, quxPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString()) // current tick 0

		std.TestSkipHeights(1)
	})
}

func testCreateExternalIncentiveBar(t *testing.T) {
	t.Run("create external incentive gns for baz:qux:0.3% pool", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		gns.Approve(a2u(consts.STAKER_ADDR), consts.UINT64_MAX) // this includes depositGnsAmount

		CreateExternalIncentive(
			"gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:3000",
			consts.GNS_PATH,
			20000000,
			1237161600,
			1237161600+TIMESTAMP_90DAYS,
		)

		std.TestSkipHeights(1)
	})
}

func testMintPos08InRange(t *testing.T) {
	t.Run("mint position 08 in range", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		baz.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)
		qux.Approve(common.AddrToUser(consts.POOL_ADDR), consts.UINT64_MAX)

		std.TestSkipHeights(1)
		pn.Mint(
			bazPath,
			quxPath,
			fee3000,
			int32(-60),
			int32(60),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			adminAddr,
			adminAddr,
		)

		std.TestSkipHeights(1)
	})
}

func testStakeToken08(t *testing.T) {
	t.Run("stake token 08", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(8))
		StakeToken(8)
		std.TestSkipHeights(1)
	})
}

func testCollectReward08(t *testing.T) {
	t.Run("collect reward for 08 position, while warm up is in 30", func(t *testing.T) {
		std.TestSkipHeights(9)
		std.TestSetRealm(adminRealm)
		CollectReward(8, false)
		std.TestSkipHeights(1)
	})
}

func testStartExternalIncentive(t *testing.T) {
	t.Run("external incentive start block skip", func(t *testing.T) {
		std.TestSkipHeights(686)
	})
}

func testCollectReward08AfterStart(t *testing.T) {
	t.Run("collect reward for 08 position", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		CollectReward(8, false)
		std.TestSkipHeights(1)
	})
}

func testEndExternalIncentiveBar(t *testing.T) {
	t.Run("end external incentive bar", func(t *testing.T) {
		std.TestSetRealm(adminRealm)

		std.TestSkipHeights(1295572) // 종료되도록 블록 증가

		EndExternalIncentive(
			anoAdmin,
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
			"gno.land/r/onbloc/obl",
			1237161600,                  // startTimestamp
			1237161600+TIMESTAMP_90DAYS, // endTimestamp
			1296169,
		)
		//1296855
		//3888000
		//1295572

		// 종료 후 확인해야 할꺼
		// - 웜업에 따른 페널티 수량 환불
		// - 익스터널 생성 시 디파짓으로 넣은 gns 수량 환불
		// - 아직 리워드 수령하지 않은 유저는 계속 리워드 수령 가능
		// - 익스터널 종료 이후 리워드가 추가적으로 발생하면 안 됨
	})
}

func testReStakeTokenPos01(t *testing.T) {
	t.Run("re-stake token 01", func(t *testing.T) {
		std.TestSetRealm(adminRealm)
		gnft.Approve(stakerAddr, common.TokenIdFrom(1))
		StakeToken(1)
		std.TestSkipHeights(2)
	})

	t.Run("collect reward for position 01", func(t *testing.T) {
		// 웜업 100% 까지 찍은 후 언스테이킹 -> 다시 스테이킹 된 상태
		// 웜업 30% 부터 적용되야 함
		std.TestSetRealm(adminRealm)
		CollectReward(1, false)
		std.TestSkipHeights(1)
	})
}
