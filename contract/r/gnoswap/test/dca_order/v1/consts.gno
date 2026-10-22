package dca_order

import (
	u256 "gno.land/p/gnoswap/uint256/v1"

	dca "gno.land/r/gnoswap/test/dca_order"
)

const bptreeFanout = dca.DefaultBPTreeFanout

const (
	IntervalMinute int64 = 60
	IntervalHour   int64 = 60 * 60
	IntervalDay    int64 = 24 * 60 * 60
	IntervalWeek   int64 = 7 * 24 * 60 * 60
	// IntervalMonth is a fixed 30-day period; calendar months are not used so
	// every round in a group has the same length.
	IntervalMonth int64 = 30 * 24 * 60 * 60

	bpsDenominator int64 = 10_000

	// maxCreationFeeBps caps the prepaid creation fee at 10%.
	maxCreationFeeBps int64 = 1_000

	// hardMaxTotalExecutions bounds configurable order length.
	hardMaxTotalExecutions int64 = 1_000_000

	defaultCreationFeeBps        int64 = 0
	defaultMinAmountPerExecution int64 = 1
	defaultMaxTotalExecutions    int64 = 10_000
)

// allowedIntervals lists supported round intervals in ascending order.
var allowedIntervals = []int64{IntervalMinute, IntervalHour, IntervalDay, IntervalWeek, IntervalMonth}

// q128 is 2^128, the accumulator scale.
var q128 = u256.Zero().Lsh(u256.One(), 128)

// maxInt64U256 is the largest single token transfer.
var maxInt64U256 = u256.NewUint(9223372036854775807)
