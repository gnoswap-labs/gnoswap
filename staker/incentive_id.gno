package staker

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
)

func IncentiveIdCompute(incentive IncentiveKey) string {
	key := ufmt.Sprintf("%d__%d__%s", incentive.startTime, incentive.endTime, incentive.refundee.String())
	// sum256 := sha256.Sum256([]byte(key))[:]
	// return hex.EncodeToString(sum256)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
