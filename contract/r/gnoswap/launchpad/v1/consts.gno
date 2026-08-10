package launchpad

const (
	projectTier30  = int64(30)
	projectTier90  = int64(90)
	projectTier180 = int64(180)

	minuteTime = int64(60)

	minimumDepositAmount = int64(1_000_000)

	stringSplitterPad = "*PAD*"

	maxProjectConditionCount = 5

	projectMinimumStartDelayTime = minuteTime * 3 // 3 minutes
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
	projectTier30:  minuteTime * projectTier30,  // 30 minutes
	projectTier90:  minuteTime * projectTier90,  // 90 minutes
	projectTier180: minuteTime * projectTier180, // 180 minutes
}

// MUST BE IMMUTABLE, DO NOT MODIFY.
var projectTierRewardCollectableDuration = map[int64]int64{
	projectTier30:  minuteTime * 1, // 1 minutes
	projectTier90:  minuteTime * 1, // 1 minutes
	projectTier180: minuteTime * 1, // 1 minutes
}
