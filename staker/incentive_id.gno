package staker

import (
	"encoding/base64"

	"gno.land/p/demo/ufmt"
)

func incentiveIdCompute(caller, targetPoolPath, rewardToken string) string {
	key := ufmt.Sprintf("%s:%s:%s", caller, targetPoolPath, rewardToken)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
