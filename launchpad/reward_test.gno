package launchpad

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestRewardStore_CalculateRewards(t *testing.T) {
	proj := Project{
		id:          "test:100",
		startHeight: 100,
		tier30: Tier{
			startHeight: 100,
			endHeight:   200,
			tierAmount:  1000,
		},
		tier30Ratio: 30,
		tier90: Tier{
			startHeight: 100,
			endHeight:   300,
			tierAmount:  2000,
		},
		tier90Ratio: 30,
		tier180: Tier{
			startHeight: 100,
			endHeight:   400,
			tierAmount:  3000,
		},
		tier180Ratio: 40,
	}

	// TODO: avl later
	projects = make(map[string]Project)
	projects[proj.id] = proj

	rs := NewRewardStore()

	tests := []struct {
		name       string
		pid        string
		height     uint64
		wantReward *u256.Uint
		wantErr    bool
	}{
		{
			name:       "Before project start",
			pid:        proj.id,
			height:     50,
			wantReward: u256.Zero(),
			wantErr:    false,
		},
		{
			name:       "Non-existent project",
			pid:        "invalid",
			height:     150,
			wantReward: nil,
			wantErr:    true,
		},
		{
			name:       "Normal reward calculation",
			pid:        proj.id,
			height:     150,
			wantReward: calculateExpectedReward(t, 50, &proj),
			wantErr:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reward, err := rs.CalculateRewards(tt.pid, tt.height)

			if tt.wantErr {
				uassert.Error(t, err)
			}
			uassert.Equal(t, reward.ToString(), tt.wantReward.ToString())
		})
	}
}

func TestRewardStore_CalculateProjectReward(t *testing.T) {
	tests := []struct {
		name        string
		project     Project
		startHeight uint64
		endHeight   uint64
		want        *u256.Uint
	}{
		{
			name: "All tiers are active",
			project: Project{
				tier30: Tier{
					startHeight:           100,
					endHeight:             200,
					tierAmount:            1000,
					tierAmountPerBlockX96: u256.NewUint(10),
				},
				tier30Ratio: 30,
				tier90: Tier{
					startHeight:           100,
					endHeight:             300,
					tierAmount:            2000,
					tierAmountPerBlockX96: u256.NewUint(20),
				},
				tier90Ratio: 30,
				tier180: Tier{
					startHeight:           100,
					endHeight:             400,
					tierAmount:            3000,
					tierAmountPerBlockX96: u256.NewUint(30),
				},
				tier180Ratio: 40,
			},
			startHeight: 150,
			endHeight:   200,
			want:        u256.NewUint(3000), // (10+20+30) * 50 blocks
		},
		{
			name: "Start before tier",
			project: Project{
				tier30: Tier{
					startHeight:           100,
					endHeight:             200,
					tierAmount:            1000,
					tierAmountPerBlockX96: u256.NewUint(10),
				},
				tier30Ratio: 100,
				tier90: Tier{
					startHeight:           300,
					endHeight:             400,
					tierAmount:            2000,
					tierAmountPerBlockX96: u256.NewUint(20),
				},
				tier90Ratio: 0,
				tier180: Tier{
					startHeight:           500,
					endHeight:             600,
					tierAmount:            3000,
					tierAmountPerBlockX96: u256.NewUint(30),
				},
				tier180Ratio: 0,
			},
			startHeight: 150,
			endHeight:   200,
			want:        u256.NewUint(500), // 10 * 50 blocks
		},
		{
			name: "Range is out of tier",
			project: Project{
				tier30: Tier{
					startHeight:           300,
					endHeight:             400,
					tierAmount:            1000,
					tierAmountPerBlockX96: u256.NewUint(10),
				},
				tier30Ratio: 100,
			},
			startHeight: 100,
			endHeight:   200,
			want:        u256.NewUint(0),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculateProjectReward(&tt.project, tt.startHeight, tt.endHeight)
			uassert.True(t, got.Eq(tt.want))
		})
	}
}

func TestRewardStore_GetRewardsInRange(t *testing.T) {
	proj := Project{
		id:          "test:200",
		startHeight: 100,
		tier30: Tier{
			startHeight: 100,
			endHeight:   200,
			tierAmount:  1000,
		},
		tier30Ratio: 30,
		tier90: Tier{
			startHeight: 100,
			endHeight:   300,
			tierAmount:  2000,
		},
		tier90Ratio: 30,
		tier180: Tier{
			startHeight: 100,
			endHeight:   400,
			tierAmount:  3000,
		},
		tier180Ratio: 40,
	}

	projects = make(map[string]Project)
	projects[proj.id] = proj

	rs := NewRewardStore()

	tests := []struct {
		name        string
		pid         string
		startHeight uint64
		endHeight   uint64
		wantReward  *u256.Uint
		wantErr     bool
	}{
		{
			name:        "Full range within single tier",
			pid:         proj.id,
			startHeight: 100,
			endHeight:   200,
			wantReward:  calculateExpectedReward(t, 100, &proj),
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reward, err := rs.GetRewardsInRange(tt.pid, tt.startHeight, tt.endHeight)
			if tt.wantErr {
				uassert.Error(t, err)
				return
			}
			uassert.NoError(t, err)
			uassert.True(t, reward.Eq(tt.wantReward))
		})
	}
}

func TestRewardStore_GetAccumulatedRewards(t *testing.T) {
	rs := NewRewardStore()

	testPid := "test:100"
	testReward := u256.NewUint(1000)

	tests := []struct {
		name    string
		setup   func()
		pid     string
		want    *u256.Uint
		wantErr bool
	}{
		{
			name: "search existing project",
			setup: func() {
				rs.accumulatedRewards.Set(testPid, testReward)
			},
			pid:     testPid,
			want:    testReward,
			wantErr: false,
		},
		{
			name:    "search non-existent project",
			setup:   func() {},
			pid:     "non:existent",
			want:    u256.Zero(),
			wantErr: false,
		},
		{
			name: "search project with zero reward",
			setup: func() {
				rs.accumulatedRewards.Set("zero:reward", u256.Zero())
			},
			pid:     "zero:reward",
			want:    u256.Zero(),
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			got, err := rs.GetAccumulatedRewards(tt.pid)
			if tt.wantErr {
				uassert.Error(t, err)
				return
			}
			uassert.NoError(t, err)
			uassert.True(t, got.Eq(tt.want))
		})
	}
}

func TestRewardStore_UpdateRewardSnapshot(t *testing.T) {
	t.Run("Create and save snapshot", func(t *testing.T) {
		rs, project := setupRewardStoreTest(t)

		err := rs.UpdateRewardSnapshot(project.id)
		uassert.NoError(t, err)

		height := uint64(std.GetHeight())
		key := createSnapshotkey(project.id, height)

		snapshotValue, exists := rs.rewardSnapshots.Get(key)
		if !exists {
			t.Error("snapshot not saved")
			return
		}

		snapshot := snapshotValue.(*RewardSnapshot)
		uassert.Equal(t, height, snapshot.Height)

		// check each tier reward
		tiers := []string{"30", "90", "180"}
		for _, tier := range tiers {
			reward, exists := snapshot.TierRewards.Get(tier)
			uassert.True(t, exists)
			uassert.False(t, reward.(*u256.Uint).IsZero())
		}
	})

	t.Run("non-existent project", func(t *testing.T) {
		rs, _ := setupRewardStoreTest(t)

		err := rs.UpdateRewardSnapshot("invalid:id")
		uassert.Error(t, err)
	})

	t.Run("snapshot before project start", func(t *testing.T) {
		rs, project := setupRewardStoreTest(t)

		// set height before project start
		std.TestSkipHeights(50) // < project.startHeight(100)

		err := rs.UpdateRewardSnapshot(project.id)
		uassert.NoError(t, err)

		key := createSnapshotkey(project.id, 50)
		snapshotValue, exists := rs.rewardSnapshots.Get(key)
		uassert.False(t, exists)
	})
}

// Helper functions for tests

func setupRewardStoreTest(t *testing.T) (*RewardStore, *Project) {
	t.Helper()

	rs := NewRewardStore()

	project := &Project{
		id:          "test:100",
		startHeight: 100,
		tier30: Tier{
			startHeight:           100,
			endHeight:             200,
			tierAmount:            1000,
			tierAmountPerBlockX96: u256.NewUint(10),
		},
		tier30Ratio: 30,
		tier90: Tier{
			startHeight:           100,
			endHeight:             300,
			tierAmount:            2000,
			tierAmountPerBlockX96: u256.NewUint(20),
		},
		tier90Ratio: 30,
		tier180: Tier{
			startHeight:           100,
			endHeight:             400,
			tierAmount:            3000,
			tierAmountPerBlockX96: u256.NewUint(30),
		},
		tier180Ratio: 40,
	}

	projects = make(map[string]Project)
	projects[project.id] = *project

	std.TestSkipHeights(150)

	return rs, project
}

// region: helper

func calculateExpectedReward(t *testing.T, blocks uint64, project *Project) *u256.Uint {
	t.Helper()

	totalReward := u256.Zero()

	tiers := []struct {
		tier  *Tier
		ratio uint64
	}{
		{&project.tier30, project.tier30Ratio},
		{&project.tier90, project.tier90Ratio},
		{&project.tier180, project.tier180Ratio},
	}

	for _, t := range tiers {
		tierReward := new(u256.Uint).Mul(
			calcTierRewardPerBlock(t.tier, t.ratio),
			u256.NewUint(blocks),
		)

		totalReward = new(u256.Uint).Add(totalReward, tierReward)
	}

	return totalReward
}

func calculateExpectedRewardWithEndedTier(t *testing.T, height uint64, project *Project) *u256.Uint {
	t.Helper()

	totalReward := u256.Zero()

	tiers := []struct {
		tier  *Tier
		ratio uint64
	}{
		{&project.tier30, project.tier30Ratio},
		{&project.tier90, project.tier90Ratio},
		{&project.tier180, project.tier180Ratio},
	}

	for _, t := range tiers {
		// add the full reward if the tier has ended
		if t.tier.endHeight < height {
			blocks := t.tier.endHeight - t.tier.startHeight
			tickReward := new(u256.Uint).Mul(
				calcTierRewardPerBlock(t.tier, t.ratio),
				u256.NewUint(blocks),
			)
			totalReward = new(u256.Uint).Add(totalReward, tickReward)
		} else {
			blocks := height - t.tier.startHeight
			tierReward := new(u256.Uint).Mul(
				calcTierRewardPerBlock(t.tier, t.ratio),
				u256.NewUint(blocks),
			)
			totalReward = new(u256.Uint).Add(totalReward, tierReward)
		}
	}

	return totalReward
}
