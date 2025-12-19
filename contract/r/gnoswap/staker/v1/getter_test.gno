package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
)

// TestMakeExternalPositionsNode_TimestampCalculation is a regression test for a bug
// where runtime.ChainHeight() (block height) was incorrectly used with timestamps.
func TestMakeExternalPositionsNode_TimestampCalculation(t *testing.T) {
	baseTime := time.Now().Unix()

	tests := []struct {
		name                    string
		incentiveStartTimestamp int64
		stakedTime              int64
		expectedMaxValue        int64
	}{
		{
			name:                    "position staked before incentive",
			incentiveStartTimestamp: baseTime - 100,
			stakedTime:              baseTime - 200,
			expectedMaxValue:        baseTime - 100,
		},
		{
			name:                    "position staked after incentive",
			incentiveStartTimestamp: baseTime - 200,
			stakedTime:              baseTime - 100,
			expectedMaxValue:        baseTime - 100,
		},
		{
			name:                    "same start time",
			incentiveStartTimestamp: baseTime - 150,
			stakedTime:              baseTime - 150,
			expectedMaxValue:        baseTime - 150,
		},
		{
			name:                    "future incentive start (not started yet)",
			incentiveStartTimestamp: baseTime + 1000,
			stakedTime:              baseTime - 100,
			expectedMaxValue:        baseTime + 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			position := ApiExternalDebugPosition{
				PositionId:      1,
				StakedTime:      tt.stakedTime,
				StakedTimestamp: tt.stakedTime,
				Incentive: []ApiExternalDebugIncentive{
					{
						PoolPath:         "gno.land/r/test/pool",
						StartTimestamp:   tt.incentiveStartTimestamp,
						EndTimestamp:     baseTime + 1000,
						StartHeight:      100,
						RewardAmount:     "1000",
						RewardPerSecond:  "10",
						TokenAmountFull:  1000,
						TokenAmountToGive: 1000,
					},
				},
			}

			currentTime := time.Now().Unix()
			maxValue := max(tt.incentiveStartTimestamp, tt.stakedTime)
			calculatedDuration := currentTime - maxValue

			uassert.Equal(t, tt.expectedMaxValue, maxValue)

			nodes := makeExternalPositionsNode([]ApiExternalDebugPosition{position})
			uassert.True(t, len(nodes) > 0, "must return nodes")

			incentiveArray := nodes[0].MustKey("incentive").MustArray()
			uassert.True(t, len(incentiveArray) > 0, "must have incentive")

			actualDuration := int64(incentiveArray[0].MustKey("stakedOrExternalDuration").MustNumeric())

			if calculatedDuration < 0 {
				uassert.Equal(t, int64(0), actualDuration, "negative duration must be clamped to 0")
			} else {
				uassert.True(t, calculatedDuration > 0, "duration must be positive")
				uassert.True(t, calculatedDuration < 10000000, "duration must be reasonable")
				diff := actualDuration - calculatedDuration
				if diff < 0 {
					diff = -diff
				}
				uassert.True(t, diff <= 1, "JSON duration must match calculated duration")
			}
		})
	}
}

// TestMakeExternalPositionsNode_HeightVsTimestamp verifies the bug is fixed:
// Old bug: ChainHeight() - max(StartHeight, StakedTime) = 12345 - 1700000000 = huge negative
// Fixed: currentTime - max(StartTimestamp, StakedTime) = positive duration
func TestMakeExternalPositionsNode_HeightVsTimestamp(t *testing.T) {
	baseTime := time.Now().Unix()

	position := ApiExternalDebugPosition{
		PositionId:      1,
		StakedTime:      baseTime - 86400,
		StakedTimestamp: baseTime - 86400,
		Incentive: []ApiExternalDebugIncentive{
			{
				PoolPath:       "gno.land/r/test/pool",
				StartTimestamp: baseTime - 43200,
				StartHeight:    12245,
				EndTimestamp:   baseTime + 86400,
				RewardAmount:   "1000000",
				RewardPerSecond: "10",
				TokenAmountFull: 1000000,
				TokenAmountToGive: 1000000,
			},
		},
	}

	currentTime := time.Now().Unix()
	maxTimestamp := max(baseTime-43200, baseTime-86400)
	duration := currentTime - maxTimestamp

	uassert.True(t, duration > 0, "duration must be positive")
	uassert.True(t, duration < 100000, "duration must be reasonable (< 100000 seconds)")

	nodes := makeExternalPositionsNode([]ApiExternalDebugPosition{position})
	uassert.True(t, len(nodes) > 0, "must not panic")

	incentiveArray := nodes[0].MustKey("incentive").MustArray()
	actualDuration := int64(incentiveArray[0].MustKey("stakedOrExternalDuration").MustNumeric())
	diff := actualDuration - duration
	if diff < 0 {
		diff = -diff
	}
	uassert.True(t, diff <= 1, "JSON duration must match calculated duration")
}
