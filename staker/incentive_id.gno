package staker

import (
	"std"
)

func incentiveIdByTime(startTime, endTime uint64, creator std.Address, rewardToken string) string {
	startTimeEncode := EncodeUint(startTime)
	endTimeEncode := EncodeUint(endTime)
	creatorEncode := creator.String()

	byTimeId := []byte(startTimeEncode)
	byTimeId = append(byTimeId, ':')
	byTimeId = append(byTimeId, endTimeEncode...)
	byTimeId = append(byTimeId, ':')
	byTimeId = append(byTimeId, creatorEncode...)
	byTimeId = append(byTimeId, ':')
	byTimeId = append(byTimeId, rewardToken...)

	return string(byTimeId)
}

func incentiveIdByHeight(startHeight, endHeight uint64, creator std.Address, rewardToken string) (string, string) {
	startHeightEncode := EncodeUint(startHeight)
	endHeightEncode := EncodeUint(endHeight)
	creatorEncode := creator.String()

	byHeightId := []byte(startHeightEncode)
	byHeightId = append(byHeightId, ':')
	byHeightId = append(byHeightId, endHeightEncode...)
	byHeightId = append(byHeightId, ':')
	byHeightId = append(byHeightId, creatorEncode...)
	byHeightId = append(byHeightId, ':')
	byHeightId = append(byHeightId, rewardToken...)

	byCreatorId := []byte(creatorEncode)
	byCreatorId = append(byCreatorId, ':')
	byCreatorId = append(byCreatorId, startHeightEncode...)
	byCreatorId = append(byCreatorId, ':')
	byCreatorId = append(byCreatorId, endHeightEncode...)
	byCreatorId = append(byCreatorId, ':')
	byCreatorId = append(byCreatorId, rewardToken...)

	return string(byHeightId), string(byCreatorId)
}