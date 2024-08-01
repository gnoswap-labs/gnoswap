package staker

import (
	"encoding/base64"

	"std"

	"gno.land/p/demo/ufmt"
)

func incentiveIdCompute(caller std.Address, targetPoolPath, rewardToken string, startTimestamp, endTimestamp, height int64) string {
	key := ufmt.Sprintf("%s:%s:%s:%d:%d:%d", caller.String(), targetPoolPath, rewardToken, startTimestamp, endTimestamp, height)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
