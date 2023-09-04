package staker

import (
	"encoding/base64"

	"gno.land/p/demo/ufmt"
)

func incentiveIdCompute(incentive IncentiveKey) string {
	key := ufmt.Sprintf("%d__%d__%s", incentive.startTime, incentive.endTime, incentive.refundee.String())

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
