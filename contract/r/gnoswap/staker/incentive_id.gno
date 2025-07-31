package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// Counter for generating unique incentive IDs
var incentiveCounter = NewCounter()

// nextIncentiveID generates a new unique incentive ID using creator address, block height and counter
func nextIncentiveID(creator std.Address, height int64) string {
	return makeIncentiveID(creator, height, incentiveCounter.next())
}

// makeIncentiveID formats an incentive ID string from the given components
// incentive id format: creator:height:index
func makeIncentiveID(creator std.Address, height int64, index int64) string {
	return ufmt.Sprintf("%s:%d:%d", creator.String(), height, index)
}
