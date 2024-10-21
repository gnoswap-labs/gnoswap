package launchpad

const (
	minimumGnsAmount = 1_000_000
)

// // pool tier
// const (
// 	TIMESTAMP_180DAYS = uint64(180 * 24 * 60 * 60) // 15552000
// 	TIMESTAMP_90DAYS  = uint64(90 * 24 * 60 * 60)  // 7776000
// 	TIMESTAMP_30DAYS  = uint64(30 * 24 * 60 * 60)  // 2592000
// )

// // claim wait duration for pool tier
// const (
// 	TIMESTAMP_14DAYS = uint64(14 * 24 * 60 * 60) // 1209600, for 180 days
// 	TIMESTAMP_7DAYS  = uint64(7 * 24 * 60 * 60)  // 604800, for 90 days
// 	TIMESTAMP_3DAYS  = uint64(3 * 24 * 60 * 60)  // 259200, for 30 days
// )

// TODO: REMOVE AFTER QA (make time shorter for qa)
const (
	TIMESTAMP_180DAYS = uint64(180 * 60)
	TIMESTAMP_14DAYS  = uint64(14 * 60)

	TIMESTAMP_90DAYS = uint64(90 * 60)
	TIMESTAMP_7DAYS  = uint64(7 * 60)

	TIMESTAMP_30DAYS = uint64(30 * 60)
	TIMESTAMP_3DAYS  = uint64(3 * 60)
)
