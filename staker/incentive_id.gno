package staker

import (
	"encoding/base64"

	"gno.land/p/demo/ufmt"
)

func incentiveIdCompute(targetPoolPath, rewardToken string) string {
	key := ufmt.Sprintf("%s_%s", targetPoolPath, rewardToken)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
