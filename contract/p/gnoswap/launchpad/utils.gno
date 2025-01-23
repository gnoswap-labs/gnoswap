package launchpad

import (
	"errors"
)

func estimateTimeToHeight(
	avgBlockTimeMs, timestamp uint64,
) (uint64, error) {
	if avgBlockTimeMs == 0 {
		return 0, errors.New("avgBlockTimeMs cannot be 0")
	}
	return timestamp * 1000 / avgBlockTimeMs, nil
}
