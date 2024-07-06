package staker

import (
	"encoding/base64"

	"std"

	"gno.land/p/demo/ufmt"
)

func incentiveIdCompute(caller std.Address, targetPoolPath, rewardToken string) string {
	key := ufmt.Sprintf("%s:%s:%s", caller.String(), targetPoolPath, rewardToken)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
