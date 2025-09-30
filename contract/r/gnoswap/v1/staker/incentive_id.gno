package staker

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// Counter for generating unique incentive IDs
var incentiveCounter = NewCounter()

// nextIncentiveID generates a new unique incentive ID using creator address, timestamp and counter
func nextIncentiveID(creator std.Address, timestamp int64) string {
	return makeIncentiveID(creator, timestamp, incentiveCounter.next())
}

// makeIncentiveID formats an incentive ID string from the given components
// incentive id format: creator:timestamp:index
func makeIncentiveID(creator std.Address, timestamp int64, index int64) string {
	return ufmt.Sprintf("%s:%d:%d", creator.String(), timestamp, index)
}
