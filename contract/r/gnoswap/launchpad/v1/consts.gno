package v1

import (
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	projectTier30  = int64(30)
	projectTier90  = int64(90)
	projectTier180 = int64(180)

	dayTime = int64(24 * 60 * 60) // 86400

	minimumDepositAmount = int64(1_000_000)

	stringSplitterPad = "*PAD*"

	maxProjectConditionCount = 5

	// QA: shortened from 3 days to 10 minutes for testing.
	projectMinimumStartDelayTime = int64(10 * 60) // 10 minutes
)

// contract paths
const (
	GOV_XGNS_PATH string = "gno.land/r/gnoswap/gov/xgns"
	GNS_PATH      string = "gno.land/r/gnoswap/gns"
)

var projectTierDurations = []int64{
	projectTier30,
	projectTier90,
	projectTier180,
}

// QA: shortened tier distribution durations from 30/90/180 days to 1 day each.
var projectTierDurationTimes = map[int64]int64{
	projectTier30:  dayTime * 1, // QA: 1 day
	projectTier90:  dayTime * 1, // QA: 1 day
	projectTier180: dayTime * 1, // QA: 1 day
}

// QA: reward becomes claimable 10 minutes after start instead of 1 day.
var projectTierRewardCollectableDuration = map[int64]int64{
	projectTier30:  int64(10 * 60), // QA: 10 minutes
	projectTier90:  int64(10 * 60), // QA: 10 minutes
	projectTier180: int64(10 * 60), // QA: 10 minutes
}

var q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")
