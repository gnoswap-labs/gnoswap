package staker

import (
	"testing"

	"gno.land/p/demo/testutils"
)

func TestRewardCalculation_1_1(t *testing.T) {
	state := NewRewardState()

	current := 100
	state.addStake(10, testutils.TestAddress("alice"), 100, uint64(current), make(map[string]uint64))

	current += 100
	reward, _ := state.removeStake(testutils.TestAddress("alice"), 100, uint64(current), make(map[string]uint64))

	if reward != 100+100 {
		t.Errorf("expected reward %d, got %d", 100+100, reward)
	}
}

func TestRewardCalculation_1_2(t *testing.T) {
	state := NewRewardState()

	current := 100
	state.addStake(10, testutils.TestAddress("alice"), 100, uint64(current), make(map[string]uint64))

	current += 100
	reward, _ := state.removeStake(testutils.TestAddress("alice"), 100, uint64(current), make(map[string]uint64))
	current -= int(reward)

	if reward != 100+100 {
		t.Errorf("expected reward %d, got %d", 100+100, reward)
	}

	current += 100
	state.addStake(12, testutils.TestAddress("bob"), 100, uint64(current), make(map[string]uint64))

	current += 100
	reward, _ = state.removeStake(testutils.TestAddress("bob"), 100, uint64(current), make(map[string]uint64))
	current -= int(reward)
	if reward != 100+100 {
		t.Errorf("expected reward %d, got %d", 100+100, reward)
	}
}

func TestRewardCalculation_1_3(t *testing.T) {
	state := NewRewardState()

	// Alice takes 100 GNS
	current := 100
	state.addStake(10, testutils.TestAddress("alice"), 10, uint64(current), make(map[string]uint64))

	// Alice takes 100 GNS
	current += 100
	state.addStake(11, testutils.TestAddress("bob"), 10, uint64(current), make(map[string]uint64))

	// Alice takes 50 GNS, Bob takes 50 GNS
	current += 100
	reward, _ := state.removeStake(testutils.TestAddress("alice"), 10, uint64(current), make(map[string]uint64))
	current -= int(reward)
	if reward != 100+100+50 {
		t.Errorf("expected reward %d, got %d", 100+100+50, reward)
	}

	// Bob takes 100 GNS
	current += 100
	reward, _ = state.removeStake(testutils.TestAddress("bob"), 10, uint64(current), make(map[string]uint64))
	current -= int(reward)
	if reward != 100+50 {
		t.Errorf("expected reward %d, got %d", 100+50, reward)
	}
}

func TestRewardCalculation_1_4(t *testing.T) {
	state := NewRewardState()

	// Alice takes 100 GNS
	current := 100
	state.addStake(10, testutils.TestAddress("alice"), 10, uint64(current), make(map[string]uint64))

	// Alice takes 200GNS
	current += 200
	state.addStake(11, testutils.TestAddress("bob"), 30, uint64(current), make(map[string]uint64))

	// Alice 25, Bob 75
	current += 100
	state.addStake(12, testutils.TestAddress("charlie"), 10, uint64(current), make(map[string]uint64))

	// Alice 20, Bob 60, Charlie 20
	current += 100
	reward, _ := state.removeStake(testutils.TestAddress("alice"), 10, uint64(current), make(map[string]uint64))
	current -= int(reward)
	if reward != 100+200+25+20 {
		t.Errorf("expected reward %d, got %d", 100+200+25+20, reward)
	}

	// Bob 75, Charlie 25
	current += 100
	reward, _ = state.removeStake(testutils.TestAddress("bob"), 30, uint64(current), make(map[string]uint64))
	current -= int(reward)
	if reward != 75+60+75 {
		t.Errorf("expected reward %d, got %d", 75+60+75, reward)
	}
}

func TestRemoveStake(t *testing.T) {
	state := NewRewardState()
	staker := testutils.TestAddress("staker")

	// set initial stake
	initialStake := uint64(10000000) // 10 GNS
	currentBalance := uint64(1000000000)
	currentProtocolFeeBalances := make(map[string]uint64)

	// add initial stake
	state.addStake(1, staker, initialStake, currentBalance, currentProtocolFeeBalances)

	t.Run("partial unstake test", func(t *testing.T) {
		// unstake half of the initial stake
		partialAmount := uint64(5000000) // 5 GNS

		_, protocolFeeRewards := state.removeStake(
			staker,
			partialAmount,
			currentBalance,
			currentProtocolFeeBalances,
		)

		// check if the staker info still exists
		stakerInfoValue, exists := state.stakerInfos.Get(staker.String())
		if !exists {
			t.Error("staker info is completely deleted")
		}

		// check the remaining stake amount
		stakerInfo := stakerInfoValue.(StakerRewardInfo)
		expectedRemainingStake := initialStake - partialAmount
		if stakerInfo.StakedAmount != expectedRemainingStake {
			t.Errorf("wrong remaining stake amount: expected %d, got %d",
				expectedRemainingStake, stakerInfo.StakedAmount)
		}

		// check the total stake amount
		if state.totalXGNSStake != expectedRemainingStake {
			t.Errorf("wrong total stake amount: expected %d, got %d",
				expectedRemainingStake, state.totalXGNSStake)
		}

		// check protocol fee rewards
		if len(protocolFeeRewards) == 0 {
			t.Error("expected non-empty protocol fee rewards")
		}
	})

	t.Run("full unstake test", func(t *testing.T) {
		// unstake the remaining amount
		remainingAmount := uint64(5000000) // 5 GNS

		_, protocolFeeRewards := state.removeStake(
			staker,
			remainingAmount,
			currentBalance,
			currentProtocolFeeBalances,
		)

		// check if the staker info is deleted
		_, exists := state.stakerInfos.Get(staker.String())
		if exists {
			t.Error("staker info is not deleted after full unstake")
		}

		// check if the total stake amount is 0
		if state.totalXGNSStake != 0 {
			t.Errorf("wrong total stake amount: expected 0, got %d",
				state.totalXGNSStake)
		}

		// check protocol fee rewards
		if len(protocolFeeRewards) == 0 {
			t.Error("expected non-empty protocol fee rewards")
		}
	})
}
