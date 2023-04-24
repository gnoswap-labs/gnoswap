package staker

import (
	"std"
	"encoding/base64"

	"gno.land/p/demo/ufmt"
)

type IncentiveKey struct {
	// rewardToken std.Address
	// pool std.Address
	startTime bigint
	endTime bigint
	refundee std.Address
}


func IncentiveIdCompute(incentive IncentiveKey) (string) {
	key := ufmt.Sprintf("%d__%d__%s", incentive.startTime, incentive.endTime, incentive.refundee.String())
	// sum256 := sha256.Sum256([]byte(key))[:]
	// return hex.EncodeToString(sum256)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}