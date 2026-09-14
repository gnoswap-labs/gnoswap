package launchpad

const (
	projectTier30  = int64(30)
	projectTier90  = int64(90)
	projectTier180 = int64(180)

	minuteTime = int64(60)
	dayTime    = int64(24 * 60 * 60) // 86400

	minimumDepositAmount = int64(1_000_000)

	stringSplitterPad = "*PAD*"

	maxProjectConditionCount = 5

	projectMinimumStartDelayTime = minuteTime * 10 // 10 minutes
)

// contract paths
const (
	GOV_XGNS_PATH string = "gno.land/r/gnoswap/gov/xgns"
	GNS_TOKEN_KEY string = "gno.land/r/gnoswap/gns.GNS"
)

// MUST BE IMMUTABLE, DO NOT MODIFY.
var projectTierDurations = []int64{
	projectTier30,
	projectTier90,
	projectTier180,
}

// MUST BE IMMUTABLE, DO NOT MODIFY.
var projectTierDurationTimes = map[int64]int64{
	projectTier30:  dayTime * 1, // 1 day
	projectTier90:  dayTime * 2, // 2 days
	projectTier180: dayTime * 3, // 3 days
}

// MUST BE IMMUTABLE, DO NOT MODIFY.
var projectTierRewardCollectableDuration = map[int64]int64{
	projectTier30:  minuteTime * 10, // 10 minutes
	projectTier90:  minuteTime * 10, // 10 minutes
	projectTier180: minuteTime * 10, // 10 minutes
}
