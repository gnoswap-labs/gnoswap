package staker

import (
	"std"
	"testing"


	"gno.land/p/demo/testutils"

	"gno.land/r/foo"
	"gno.land/r/bar"

	rt "gno.land/r/reward" // reward Token

	pool "gno.land/r/pool"
	position "gno.land/r/position"
)


var (
	_maxIncentiveStartLeadTime bigint = 1000000
	_maxIncentiveDuration bigint = 1000000

	ci = testutils.TestAddress("ci") // Create Incentive Caller
	rf = testutils.TestAddress("rf") // Refundee
	rc = testutils.TestAddress("rc") // Recipient
	lp = testutils.TestAddress("lp01") // Liquidity Provider
	oa = testutils.TestAddress("oa") // Other Address
)

func init() {
	std.TestSetOrigCaller(ci)
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet() // x11

	std.TestSetOrigCaller(lp)
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet() // foo x5
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet() // bar x5
}

// func TestDebug(t *testing.T) {
// 	println(ci, "ci")
// 	println(rf, "rf")
// 	println(rc, "rc")
// 	println(lp, "lp01")
// 	println(GetOrigPkgAddr(), "staker contract")
// }


func TestGoodScenario(t *testing.T) {
	// 1. Pool Init
	var (
		_fee bigint = 3000
		_tickSpacing bigint = 10
		_sqrtPrice bigint = 130621891405341611593710811006
	)
	pool.Init(_fee, _tickSpacing, _sqrtPrice)
	std.TestSetOrigCaller(lp)
	foo.Approve(a2u(GetOrigPkgAddr()), 50000000)
	bar.Approve(a2u(GetOrigPkgAddr()), 50000000)
	foo.Approve(a2u(lp), 50000000)
	bar.Approve(a2u(lp), 50000000)

	// // 2. First Mint by lp
	std.TestSetOrigCaller(lp)
	_mintParams := position.MintParams{
		token0: std.Address("token0"),
		token1: std.Address("token1"),
		fee: bigint(3000), // not used
		tickLower: bigint(9000),
		tickUpper: bigint(11000),
		amount0Desired: bigint(1000),
		amount1Desired: bigint(1000),
		amount0Min: bigint(1),
		amount1Min: bigint(1),
		recipient: GetOrigPkgAddr(), // always nft manager contract address
		deadline: bigint(1234567890),
	}
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(_mintParams)	
	std.TestSkipTimestamps(1)
	
	// 3. Init Incentive Program
	Init(_maxIncentiveStartLeadTime, _maxIncentiveDuration)

	// 4. Create Incentive
	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 99,
		refundee: rf,
	}
	std.TestSetOrigCaller(ci)
	CreateIncentive(_incentiveKey, 50000000)

	// 5. Stake NFT to Incentive Program
	std.TestSetOrigCaller(lp)
	StakeToken(_incentiveKey, _posTokenId)
	
	// 6. Waiting until deadlien(99) and some extra time
	std.TestSkipTimestamps(140)
	
	// // 6.1 debug progress
	// {
	// 	std.TestSkipTimestamps(20) // little
	// 	_littleReward, _littleSecondsInsideX128 := getRewardInfo(_incentiveKey, _posTokenId)
	// 	println()
	// 	println("LITTLE")
	// 	println("ㄴ reward:", _littleReward)
	// 	println("ㄴ secondsInsideX128:", _littleSecondsInsideX128)
	// 	println("ㄴ secondsInside:", _littleSecondsInsideX128 / Q128)
		

	// 	std.TestSkipTimestamps(30) // half
	// 	_halfReward, _halfSecondsInsideX128 := getRewardInfo(_incentiveKey, _posTokenId)
	// 	println()
	// 	println("HALF WAY")
	// 	println("ㄴ reward:", _halfReward)
	// 	println("ㄴ secondsInsideX128:", _halfSecondsInsideX128)
	// 	println("ㄴ secondsInside:", _halfSecondsInsideX128 / Q128)
		
	// 	std.TestSkipTimestamps(60) // after deadline
	// 	_finReward, _finSecondsInsideX128 := getRewardInfo(_incentiveKey, _posTokenId)
	// 	println()
	// 	println("FINISH")
	// 	println("ㄴ reward:", _finReward)
	// 	println("ㄴ secondsInsideX128:", _finSecondsInsideX128)
	// 	println("ㄴ secondsInside:", _finSecondsInsideX128 / Q128)
	// }
	

	// 7. Unstake NFT from Incentive Program
	UnstakeToken(_incentiveKey, _posTokenId)

	// 7.5. claim bit of reward
	_oldBal := rt.BalanceOf(a2u(rf))
	claimReward(rf, 100)
	_newBal := rt.BalanceOf(a2u(rf))
	shouldEQ(t, _oldBal, bigint(0))
	shouldEQ(t, _newBal - _oldBal, bigint(100))

	// (optional) send to other address
	claimReward(oa, 123456)

	// 8. Withdraw NFT from Incentive Program
	std.TestSetOrigCaller(lp)
	WithdrawToken(_posTokenId, GetOrigCaller())


	// 9. End Incentive Program
	_refundeeOldBalance := rt.BalanceOf(a2u(rf))

	// _refund := EndIncentive(_incentiveKey)
	// println("End Incentive with")
	// println("ㄴ refund:", _refund)
	// println("ㄴ refundee:", _incentiveKey.refundee)
	// println("ㄴ before end:", _refundeeOldBalance)
	// println("ㄴ after end:", rt.BalanceOf(a2u(rf)))
	// println()
}


func TestBadScenario(t *testing.T) {
	// // 1. Pool Init
	// var (
	// 	_fee bigint = 3000
	// 	_tickSpacing bigint = 10
	// 	_sqrtPrice bigint = 130621891405341611593710811006
	// )
	// pool.Init(_fee, _tickSpacing, _sqrtPrice)
	// std.TestSetOrigCaller(lp)
	// foo.Approve(a2u(GetOrigPkgAddr()), 50000000)
	// bar.Approve(a2u(GetOrigPkgAddr()), 50000000)
	// foo.Approve(a2u(lp), 50000000)
	// bar.Approve(a2u(lp), 50000000)

	// 2. Second Mint by lp
	std.TestSetOrigCaller(lp)
	_mintParams := position.MintParams{
		token0: std.Address("token0"),
		token1: std.Address("token1"),
		fee: bigint(3000), // not used
		tickLower: bigint(9000),
		tickUpper: bigint(11000),
		amount0Desired: bigint(1000),
		amount1Desired: bigint(1000),
		amount0Min: bigint(1),
		amount1Min: bigint(1),
		recipient: GetOrigPkgAddr(), // always nft manager contract address
		deadline: bigint(2345678901),
	}
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(_mintParams)
	
	// 3. Init Incentive Program
	// Init(_maxIncentiveStartLeadTime, _maxIncentiveDuration)

	// 4. Create Incentive
	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 99,
		refundee: rf,
	}
	std.TestSetOrigCaller(ci)
	CreateIncentive(_incentiveKey, 50000000)

	// 5. Stake NFT to Incentive Program
	std.TestSetOrigCaller(lp)
	StakeToken(_incentiveKey, _posTokenId)

	// 6. Waiting - not enough
	std.TestSkipTimestamps(97)

	// 7. Unstake NFT from Incentive Program
	// should panic incentive not ended
	shouldPanic(t, func() { UnstakeToken(_incentiveKey, _posTokenId) })

	// 8. Withdraw NFT from Incentive Program
	// should panic cannot withdraw token while staked
	shouldPanic(t, func() { WithdrawToken(_posTokenId, GetOrigCaller()) })

	// 9. End Incentive Program
	// should panic cannot end incentive before end time
	shouldPanic(t, func() { EndIncentive(_incentiveKey) })
}


func TestBadInit(t *testing.T) {
	// should panic Already initialized
	// Init(_maxIncentiveStartLeadTime, _maxIncentiveDuration)
	shouldPanic(t, func() { Init(_maxIncentiveStartLeadTime, _maxIncentiveDuration) })
}


func TestBadCreateIncentive(t *testing.T) {
	{
		// should panic reward must be positive
		_incentiveKey := IncentiveKey{
			startTime: GetTimestamp() + 1,
			endTime: GetTimestamp() + 2,
			refundee: rf,
		}
		std.TestSetOrigCaller(ci)
		// CreateIncentive(_incentiveKey, 0)
		shouldPanic(t, func() { CreateIncentive(_incentiveKey, 0) })
	}

	{
		// should panic start time must be now or in the future
		_incentiveKey := IncentiveKey{
			startTime: GetTimestamp() - 1,
			endTime: GetTimestamp() + 2,
			refundee: rf,
		}
		std.TestSetOrigCaller(ci)
		// CreateIncentive(_incentiveKey, 10000)
		shouldPanic(t, func() { CreateIncentive(_incentiveKey, 10000) })
	}

	{
		// should panic start time too far into future
		_incentiveKey := IncentiveKey{
			startTime: GetTimestamp() + 1234567890,
			endTime: GetTimestamp() + 2345678901,
			refundee: rf,
		}
		std.TestSetOrigCaller(ci)
		// CreateIncentive(_incentiveKey, 10000)
		shouldPanic(t, func() { CreateIncentive(_incentiveKey, 10000) })
	}

	{
		// should panic start time must be before end time
		_incentiveKey := IncentiveKey{
			startTime: GetTimestamp() + 12345,
			endTime: GetTimestamp() + 12344,
			refundee: rf,
		}
		std.TestSetOrigCaller(ci)
		// CreateIncentive(_incentiveKey, 10000)
		shouldPanic(t, func() { CreateIncentive(_incentiveKey, 10000) })
	}

	{
		// should panic incentive duration is too long
		_incentiveKey := IncentiveKey{
			startTime: GetTimestamp() + 1000000,
			endTime: GetTimestamp() + 2000001,
			refundee: rf,
		}
		std.TestSetOrigCaller(ci)
		// CreateIncentive(_incentiveKey, 10000)
		shouldPanic(t, func() { CreateIncentive(_incentiveKey, 10000) })
	}
}


func TestBadStakeToken(t *testing.T) {
	// ready
	std.TestSetOrigCaller(lp)
	_mintParams := position.MintParams{
		token0: std.Address("token0"),
		token1: std.Address("token1"),
		fee: bigint(3000), // not used
		tickLower: bigint(9000),
		tickUpper: bigint(11000),
		amount0Desired: bigint(1000),
		amount1Desired: bigint(1000),
		amount0Min: bigint(1),
		amount1Min: bigint(1),
		recipient: GetOrigPkgAddr(), // always nft manager contract address
		deadline: bigint(2345678901),
	}

	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 88,
		refundee: rf,
	}
	std.TestSetOrigCaller(ci)
	CreateIncentive(_incentiveKey, 10000)

	std.TestSetOrigCaller(lp)
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(_mintParams)
	
	{
		// should panic only owner can stake token
		std.TestSetOrigCaller(oa)
		// StakeToken(_incentiveKey, _posTokenId)
		shouldPanic(t, func() { StakeToken(_incentiveKey, _posTokenId) })
	}

	{
		// should panic incentive not started
		std.TestSetOrigCaller(lp)
		std.TestSkipTimestamps(-1)
		// StakeToken(_incentiveKey, _posTokenId)
		shouldPanic(t, func() { StakeToken(_incentiveKey, _posTokenId) })
		std.TestSkipTimestamps(1)
	}

	{
		// should panic incentive ended
		std.TestSetOrigCaller(lp)
		std.TestSkipTimestamps(100)
		shouldPanic(t, func() { StakeToken(_incentiveKey, _posTokenId) })
		std.TestSkipTimestamps(-100)
	}

	{
		// should panic non-existent incentive
		std.TestSetOrigCaller(lp)
		_tmpIncentiveId := "MTIzNDU2ODEyOF9fMTIzNDU2ODIxNl9fZzF3Zm45N2g2bHRhMDQ3aDZsdGEwNDdoNmx0YTA0N2g2bGhleWZoag=="
		// incentives[_tmpIncentiveId].totalRewardUnclaimed = 0
		_tmp, ok := incentives.Get(_tmpIncentiveId)
		var tmp Incentive
		if ok {
			tmp = _tmp.(Incentive)
			tmp.totalRewardUnclaimed = 0
		} else {
			tmp = Incentive{}
		}
		incentives.Set(_tmpIncentiveId, tmp)

		// StakeToken(_incentiveKey, _posTokenId)
		shouldPanic(t, func() { StakeToken(_incentiveKey, _posTokenId) })

		// set correct value for further test
		// incentives[_tmpIncentiveId].totalRewardUnclaimed = 10000
		_tmp2, ok2 := incentives.Get(_tmpIncentiveId)
		var tmp2 Incentive
		tmp2 = _tmp2.(Incentive)
		tmp2.totalRewardUnclaimed = 10000
		incentives.Set(_tmpIncentiveId, tmp2)
	}

	{
		// should panic token already staked
		std.TestSetOrigCaller(lp)
		StakeToken(_incentiveKey, _posTokenId)
		std.TestSetOrigCaller(GetOrigPkgAddr())
		// StakeToken(_incentiveKey, _posTokenId)
		shouldPanic(t, func() { StakeToken(_incentiveKey, _posTokenId) })
	}
	
	{
		// should panic cannot stake token with 0 liquidity
		// XXX 
	}
}


func TestBadUnstakeToken(t *testing.T) {
	// tid 3 is staked with lp as owner
	// ready
	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 88,
		refundee: rf,
	}

	{
		// should panic incentive not ended
		std.TestSetOrigCaller(lp)
		// UnstakeToken(_incentiveKey, "3")
		shouldPanic(t, func() { UnstakeToken(_incentiveKey, "3") })
	}

	{
		// should panic stake does not exist
		std.TestSetOrigCaller(lp)
		std.TestSkipTimestamps(100)
		UnstakeToken(_incentiveKey, "3")
		// UnstakeToken(_incentiveKey, "3")
		shouldPanic(t, func() { UnstakeToken(_incentiveKey, "3") })
	}
}


func TestBadWithdrawToken(t *testing.T) {
	// ready
	std.TestSetOrigCaller(lp)
	_mintParams := position.MintParams{
		token0: std.Address("token0"),
		token1: std.Address("token1"),
		fee: bigint(3000), // not used
		tickLower: bigint(9000),
		tickUpper: bigint(11000),
		amount0Desired: bigint(1000),
		amount1Desired: bigint(1000),
		amount0Min: bigint(1),
		amount1Min: bigint(1),
		recipient: GetOrigPkgAddr(), // always nft manager contract address
		deadline: bigint(2345678901),
	}

	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 88,
		refundee: rf,
	}
	std.TestSetOrigCaller(ci)
	CreateIncentive(_incentiveKey, 10000)

	std.TestSetOrigCaller(lp)
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(_mintParams)

	// stake
	std.TestSetOrigCaller(lp)
	stakeToken(_incentiveKey, _posTokenId)

	{
		// should panic cannot withdraw to staker
		std.TestSetOrigCaller(lp)
		// WithdrawToken("4", GetOrigPkgAddr())
		shouldPanic(t, func() { WithdrawToken("4", GetOrigPkgAddr()) })
	}

	{
		// should panic cannot withdraw token wihle staked
		std.TestSetOrigCaller(lp)
		// WithdrawToken("4", oa)
		shouldPanic(t, func() { WithdrawToken("4", oa) })
	}

	{
		// should panic only owner can withdraw token
		std.TestSetOrigCaller(lp)
		std.TestSkipTimestamps(100)
		UnstakeToken(_incentiveKey, "4")
		
		std.TestSetOrigCaller(oa)
		// WithdrawToken("4", oa)
		shouldPanic(t, func() { WithdrawToken("4", oa) })
	}
}


func TestBadEndIncentive(t *testing.T) {
	// ready
	std.TestSetOrigCaller(lp)
	_mintParams := position.MintParams{
		token0: std.Address("token0"),
		token1: std.Address("token1"),
		fee: bigint(3000), // not used
		tickLower: bigint(9000),
		tickUpper: bigint(11000),
		amount0Desired: bigint(1000),
		amount1Desired: bigint(1000),
		amount0Min: bigint(1),
		amount1Min: bigint(1),
		recipient: GetOrigPkgAddr(), // always nft manager contract address
		deadline: bigint(2345678901),
	}

	_incentiveKey := IncentiveKey{
		startTime: GetTimestamp(),
		endTime: GetTimestamp() + 88,
		refundee: rf,
	}
	std.TestSetOrigCaller(ci)
	CreateIncentive(_incentiveKey, 10000)

	std.TestSetOrigCaller(lp)
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(_mintParams)

	// stake
	std.TestSetOrigCaller(lp)
	stakeToken(_incentiveKey, _posTokenId)

	{
		// should panic cannot end incentive before end time
		// EndIncentive(_incentiveKey)
		shouldPanic(t, func() { EndIncentive(_incentiveKey) })
		std.TestSkipTimestamps(200)
	}

	{
		// should panic cannot end incentive while deposits are staked
		std.TestSetOrigCaller(lp)
		// EndIncentive(_incentiveKey)
		shouldPanic(t, func() { EndIncentive(_incentiveKey) })
		UnstakeToken(_incentiveKey, "5")
	}

	{
		// no refund available
		std.TestSetOrigCaller(GetOrigPkgAddr())
		// EndIncentive(_incentiveKey)
		EndIncentive(_incentiveKey)
		shouldPanic(t, func() { EndIncentive(_incentiveKey) })
	}

	// end non exist incentive
	_NonIncentiveKey := IncentiveKey{
		startTime: GetTimestamp() + 123,
		endTime: GetTimestamp() + 678,
		refundee: oa,
	}
}



// helper
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}