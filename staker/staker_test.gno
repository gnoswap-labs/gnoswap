package staker

import (
	"std"
	"testing"
	"strconv"
	// nftManager "gno.land/p/demo/v3_periphery_mock"
	// "gno.land/p/demo/s1"
)

type T interface{}

var MaxIncentiveDuration uint64 = 100000
var MaxIncentiveStartLeadTime uint64 = 100000

func Test(t *testing.T) {
	testtoken1.Init()
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)
	nftManager.Mint("1", std.GetOrigPkgAddr())
	rwTokenBalance, err := rewardToken.BalanceOf(std.GetOrigPkgAddr())

	if err != nil {
		panic(err)
	}
	// 1. create incentive
	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 99,
		refundee: std.GetOrigPkgAddr(),
	}
	CreateIncentive(incentiveKey, 10000)

	// 2. stake token
	StakeToken(incentiveKey, "1")

	// 3. waiting
	increaseBlock(100)

	// 4. unstake token
	UnstakeToken(incentiveKey, "1")

	// 5.withdraw token
	WithdrawToken("1", std.GetOrigCaller())

	// 6. End Incentive
	EndIncentive(incentiveKey)

	rwTokenBalance, err = rewardToken.BalanceOf(std.GetOrigPkgAddr())

	if err != nil {
		panic(err)
	}
	println("rwTokenBalance after", rwTokenBalance)
	TestComputeIncentiveKey(t)
}

func increaseBlock(number int64) {
	std.TestSkipHeights(number)
	std.TestSkipBlockTimestamp(number)
}

func TestInitialize(t *testing.T) {
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	expect(t, maxIncentiveDuration, 100000)
	expect(t, maxIncentiveStartLeadTime, 100000)
}

func TestComputeIncentiveKey(t *testing.T) {
	incentiveKey := IncentiveKey{
		startTime: 100,
		endTime: 1000,
		refundee: "hello",
	}

	incentiveId := computeIncentiveKey(incentiveKey)
	println("incentiveId", incentiveId)
}

func TestCreateIncentive(t *testing.T) {
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 100,
		refundee: "hello",
	}
	incentiveId := computeIncentiveKey(incentiveKey)

	incentive := &incentives[incentiveId]
	expect(t, incentives[incentiveId].totalRewardUnclaimed, 0)
	expect(t, incentives[incentiveId].totalSecondsClaimed, 0)
	expect(t, incentives[incentiveId].numberOfStakes, 0)

	CreateIncentive(incentiveKey, 10000)

	incentive = &incentives[incentiveId]

	expect(t, incentives[incentiveId].totalRewardUnclaimed, 10000)
	expect(t, incentives[incentiveId].totalSecondsClaimed, 0)
	expect(t, incentives[incentiveId].numberOfStakes, 0)
}

func TestComputeRewardAmount(t *testing.T) {
	reward, secondsInside := computeRewardAmount(1000, 0, 0, 10, 1000, 0, 1, 5)

	expect(t, reward, 100000)
	expect(t, secondsInside, 1000)
}

func TestEndIncentive(t *testing.T) {
	// Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 100,
		refundee: "hello",
	}
	incentiveId := computeIncentiveKey(incentiveKey)
	
	// CreateIncentive(incentiveKey, 10000)
	increaseBlock(101)

	refund := EndIncentive(incentiveKey)
	expect(t, refund, 10000)
}

func TestStake(t *testing.T) {
	tokenId := "2"
	// follow create incentives => user stake => after 100 block unstake
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	rwTokenBalance, err := rewardToken.BalanceOf(std.GetOrigPkgAddr())

	if err != nil {
		panic(err)
	}
	println("rwTokenBalance", rwTokenBalance)
	// 1. create incentive
	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 99,
		refundee: std.GetOrigPkgAddr(),
	}
	CreateIncentive(incentiveKey, 10000)

	// 2. stake token
	nftManager.Mint(tokenId, std.GetOrigPkgAddr())
	StakeToken(incentiveKey, tokenId)

	deposit := deposits[tokenId]
	expect(t, deposit.owner, std.GetOrigPkgAddr())
	expect(t, deposit.numberOfStakes, 1)
	expect(t, deposit.owner, std.GetOrigPkgAddr())
	println(deposit)
}

func TestClaimReward(t * testing.T) {
	tokenId := "100"
	// follow create incentives => user stake => after 100 block unstake
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	rwTokenBalance, err := rewardToken.BalanceOf(std.GetOrigPkgAddr())

	if err != nil {
		panic(err)
	}
	println("rwTokenBalance", rwTokenBalance)
	// 1. create incentive
	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 99,
		refundee: std.GetOrigPkgAddr(),
	}
	CreateIncentive(incentiveKey, 10000)

	// 2. stake token
	nftManager.Mint(tokenId, std.GetOrigPkgAddr())
	StakeToken(incentiveKey, tokenId)
	increaseBlock(50)

	reward, secondsInside := GetRewardInfo(incentiveKey, tokenId)
	println("reward", reward)
	println("secondsInside", secondsInside)
	UnstakeToken(incentiveKey, tokenId)
	rewardClaimed := ClaimReward(std.GetOrigPkgAddr(), reward)
	expect(t, rewardClaimed, reward)
}

func TestTransferDeposit(t *testing.T) {
	tokenId := "3"
	// follow create incentives => user stake => after 100 block unstake
	Initialize(MaxIncentiveDuration, MaxIncentiveStartLeadTime)

	rwTokenBalance, err := rewardToken.BalanceOf(std.GetOrigPkgAddr())

	if err != nil {
		panic(err)
	}
	println("rwTokenBalance", rwTokenBalance)
	// 1. create incentive
	incentiveKey := IncentiveKey{
		startTime: BlockTimestamp(),
		endTime: BlockTimestamp() + 99,
		refundee: std.GetOrigPkgAddr(),
	}
	CreateIncentive(incentiveKey, 10000)

	// 2. stake token
	nftManager.Mint(tokenId, std.GetOrigPkgAddr())
	StakeToken(incentiveKey, tokenId)

	deposit := deposits[tokenId]
	expect(t, deposit.owner, std.GetOrigPkgAddr())
	expect(t, deposit.numberOfStakes, 1)
	expect(t, deposit.owner, std.GetOrigPkgAddr())
	println(deposit)

	TransferDeposit(tokenId, deadAddress)
	deposit2 := deposits[tokenId]
	expect(t, deposit2.owner, deadAddress)
	expect(t, deposit2.numberOfStakes, 1)
	expect(t, deposit2.owner, deadAddress)
	println(deposit2)
}

func expect(t *testing.T, value T, expected T) {
	if value != expected {
		t.Fatalf("expected %d, got %d.", expected, value)
	}
}