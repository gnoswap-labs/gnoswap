package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// Counter for generating unique incentive IDs
var incentiveCounter = NewCounter()

// getCurrentIncentiveIndex returns the current incentive counter value
func getCurrentIncentiveIndex() int64 { return incentiveCounter.Get() }

// nextIncentiveIndex increments and returns the next incentive counter value
func nextIncentiveIndex() int64 { return incentiveCounter.next() }

// nextIncentiveID generates a new unique incentive ID using creator address, block height and counter
func nextIncentiveID(creator std.Address, height int64) string {
	return makeIncentiveID(creator, height, nextIncentiveIndex())
}

// makeIncentiveID formats an incentive ID string from the given components
// incentive id format: creator:height:index
func makeIncentiveID(creator std.Address, height int64, index int64) string {
	return ufmt.Sprintf("%s:%d:%d", creator.String(), height, index)
}
