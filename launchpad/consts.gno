package launchpad

const (
	minimumGnsAmount = 1_000_000
)

/*
// pool tier
const (
	TIMESTAMP_180DAYS = uint64(180 * 24 * 60 * 60) // 15552000
	TIMESTAMP_90DAYS  = uint64(90 * 24 * 60 * 60)  // 7776000
	TIMESTAMP_30DAYS  = uint64(30 * 24 * 60 * 60)  // 2592000
)

// claim wait duration for pool tier
const (
	TIMESTAMP_14DAYS = uint64(14 * 24 * 60 * 60) // 1209600, for 180 days
	TIMESTAMP_7DAYS  = uint64(7 * 24 * 60 * 60)  // 604800, for 90 days
	TIMESTAMP_3DAYS  = uint64(3 * 24 * 60 * 60)  // 259200, for 30 days
)
*/

// XXX: qa value, requested by @roje1
// XXX: remove after qa
const (
	TIMESTAMP_180DAYS = uint64(1080 * 60) // 1080 minutes == 18 hours
	TIMESTAMP_14DAYS  = uint64(84 * 60)   // 84 minutes

	TIMESTAMP_90DAYS = uint64(540 * 60) // 540 minutes == 9 hours
	TIMESTAMP_7DAYS  = uint64(42 * 60)  // 42 minutes

	TIMESTAMP_30DAYS = uint64(180 * 60) // 180 minutes == 3 hours
	TIMESTAMP_3DAYS  = uint64(18 * 60)  // 18 minutes
)
