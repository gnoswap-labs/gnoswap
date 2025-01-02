package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestRewardDistributor(t *testing.T) {
	setupTestDistributor := func() (*RewardDistributor, *Project, std.Address) {
		rd := &RewardDistributor{
			pendingRewards:      avl.NewTree(),
			distributionHistory: avl.NewTree(),
			lastUpdateHeight:    avl.NewTree(),
		}

		testAddr := testutils.TestAddress("test")

		project := &Project{
			id:            "test:1",
			name:          "Test Project",
			tokenPath:     "test/token",
			depositAmount: 1000000,
			recipient:     testAddr,
			startHeight:   90,
			endHeight:     10000,
			tier30: Tier{
				id:                    "test:1:30",
				collectWaitDuration:   100,
				tierAmount:           300000,
				startHeight:          100,
				endHeight:           3100,
				actualDepositAmount:  100000,
				tierAmountPerBlockX96: u256.NewUint(1000000),
			},
		}

		projects[project.id] = *project

		return rd, project, testAddr
	}

	t.Run("DistributeRewards - Distributing project rewards", func(t *testing.T) {
		rd, project, _ := setupTestDistributor()
		ds := setupTestDepositStore()

		testAddr1 := testutils.TestAddress("test1")
		testAddr2 := testutils.TestAddress("test2")

		depositId1, _ := ds.AddDeposit(project.id, testAddr1, 50000, "30")
		depositId2, _ := ds.AddDeposit(project.id, testAddr2, 50000, "30")

		err := rd.DistributeRewards(project.id)
		uassert.NoError(t, err)

		reward1, _ := rd.PendingRewards(testAddr1, project.id)
		reward2, _ := rd.PendingRewards(testAddr2, project.id)
		uassert.Equal(t, reward1.ToString(), reward2.ToString())
	})

	t.Run("DistributeUserReward - Distributing individual user rewards", func(t *testing.T) {
		t.Skip("insufficient reward")
		rd, project, testAddr := setupTestDistributor()

		initialReward := u256.NewUint(1000)
		rd.pendingRewards.Set(generateRewardKey(testAddr, project.id), initialReward)

		distributed, err := rd.DistributeUserReward(testAddr, project.id)
		uassert.NoError(t, err)

		uassert.Equal(t, distributed.ToString(), initialReward.ToString())

		remaining, _ := rd.PendingRewards(testAddr, project.id)
		uassert.True(t, remaining.IsZero())

		height := uint64(std.GetHeight())
		historyKey := generateDistributionHistoryKey(generateRewardKey(testAddr, project.id), height)
		record, exists := rd.distributionHistory.Get(historyKey)
		uassert.True(t, exists)

		distributionRecord := record.(*DistributionRecord)
		uassert.Equal(t, distributionRecord.Amount.ToString(), initialReward.ToString())
	})

	t.Run("BatchDistribute - Distributing batch rewards", func(t *testing.T) {
		t.Skip("insufficient reward")
		rd, project, _ := setupTestDistributor()

		testAddrs := []std.Address{
			testutils.TestAddress("test1"),
			testutils.TestAddress("test2"),
			testutils.TestAddress("test3"),
		}

		for _, addr := range testAddrs {
			rd.pendingRewards.Set(generateRewardKey(addr, project.id), u256.NewUint(1000))
		}

		err := rd.BatchDistribute(testAddrs, project.id)
		uassert.NoError(t, err)

		for _, addr := range testAddrs {
			remaining, _ := rd.PendingRewards(addr, project.id)
			uassert.True(t, remaining.IsZero())

			height := uint64(std.GetHeight())
			historyKey := generateDistributionHistoryKey(generateRewardKey(addr, project.id), height)
			_, exists := rd.distributionHistory.Get(historyKey)
			uassert.True(t, exists)
		}
	})

	t.Run("GetPendingRewards - Getting pending rewards", func(t *testing.T) {
		rd, project, testAddr := setupTestDistributor()

		reward, err := rd.PendingRewards(testAddr, project.id)
		uassert.NoError(t, err)
		uassert.True(t, reward.IsZero())

		expectedReward := u256.NewUint(1000)
		rd.pendingRewards.Set(generateRewardKey(testAddr, project.id), expectedReward)

		reward, err = rd.PendingRewards(testAddr, project.id)
		uassert.NoError(t, err)
		uassert.True(t, reward.Eq(expectedReward))
	})
}

func TestCalculateDepositReward(t *testing.T) {
	t.Run("Normal case", func(t *testing.T) {
		rd := NewRewardDistributor()

		project := Project{
			id: "test:1",
			tier30: Tier{
				actualDepositAmount: 100000,
				tierAmountPerBlockX96: u256.NewUint(1000000),
			},
		}
		projects[project.id] = project

		deposit := &Deposit{
			projectId: "test:1",
			amount: 50000,
			tier: "30",
			depositHeight: 100,
		}

		std.TestSkipHeights(110)

		reward, err := rd.calculateDepositReward(deposit)
		uassert.NoError(t, err)

		// expected reward calculation
		// - 10 blocks passed
		// - 50% share
		// - 1000000 per block
		// - final reward is (1000000 * 11 * 0.5) / (2^96 * 2^96)	
	})

	t.Run("tierAmountPerBlockX96가 0인 경우", func(t *testing.T) {
		rd := NewRewardDistributor()
		
		project := Project{
			id: "test:2",
			tier30: Tier{
				actualDepositAmount: 100000,
				tierAmountPerBlockX96: u256.Zero(),
			},
		}
		projects[project.id] = project

		deposit := &Deposit{
			projectId: "test:2",
			amount: 50000,
			tier: "30",
			depositHeight: 100,
		}

		reward, err := rd.calculateDepositReward(deposit)
		uassert.NoError(t, err)
		uassert.True(t, reward.IsZero())
	})

	t.Run("The current block is less than or equal to the last updated block", func(t *testing.T) {
		rd := NewRewardDistributor()
		
		project := Project{
			id: "test:3",
			tier30: Tier{
				actualDepositAmount: 100000,
				tierAmountPerBlockX96: u256.NewUint(1000000),
			},
		}
		projects[project.id] = project

		deposit := &Deposit{
			projectId: "test:3",
			amount: 50000,
			tier: "30",
			depositHeight: 100,
		}

		// Set the last update height to be higher than the current block
		rd.lastUpdateHeight.Set(deposit.projectId, uint64(200))
		std.TestSkipHeights(150)

		reward, err := rd.calculateDepositReward(deposit)
		uassert.NoError(t, err)
		uassert.True(t, reward.IsZero())
	})
}

func setupTestDepositStore() *DepositStore {
	return &DepositStore{
		deposits:            avl.NewTree(),
		depositsByProject:   avl.NewTree(),
		depositsByUser:      avl.NewTree(),
		depositsByUserProject: avl.NewTree(),
	}
}
