package staker

const (
	minimumAmount = 1_000_000 // 1 GNS

	// maxAccrualBucketsPerCollect bounds how many pending accrual buckets one
	// single-token collect folds. Whatever is left stays pending for the next collect.
	maxAccrualBucketsPerCollect = 256
	// maxStakeEventsPerCollect bounds how many of the staker's own stake events one
	// single-token collect settles. Whatever is left stays pending for the next collect.
	maxStakeEventsPerCollect = 256
)
