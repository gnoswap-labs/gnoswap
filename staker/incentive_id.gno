package staker

import (
	"std"
	"strconv"
	
	// "gno.land/p/demo/pool" 
)

type IncentiveKey {
	rewardToken std.Address
	// pool interface{}
	startTime uint64
	endTime uint64
	refundee std.Addressß
}

func IncentiveIdCompute(incentive IncentiveKey) (string) {
	key := incentive.rewardToken.String() + incentive.startTime.String() + incentive.endTime.String() + incentive.refundee.String()
	return key
}