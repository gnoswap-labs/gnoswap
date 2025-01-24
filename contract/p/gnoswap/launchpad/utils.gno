package launchpad

import (
	"errors"
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
)

func createId(prefix, suffix string) string {
	return ufmt.Sprintf("%s:%s", prefix, suffix)
}

func TierAmount(amount, ratio uint64) uint64 {
	return amount * ratio / 100
}

func calculateStartHeight(
	avgBlockTimeMs, now, start uint64,
) (uint64, error) {
	timeUntilStart := start - now
	blockDurationToStart, err := estimateTimeToHeight(avgBlockTimeMs, timeUntilStart)
	if err != nil {
		return 0, err
	}

	return uint64(std.GetHeight()) + blockDurationToStart, nil
}

func estimateTimeToHeight(
	avgBlockTimeMs, timestamp uint64,
) (uint64, error) {
	if avgBlockTimeMs == 0 {
		return 0, errors.New("avgBlockTimeMs cannot be 0")
	}
	return timestamp * 1000 / avgBlockTimeMs, nil
}

func formatUint64(v uint64) string {
	return strconv.FormatUint(v, 10)
}
