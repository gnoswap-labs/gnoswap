package staker

import "strconv"

var incentiveCounter = NewCounter()

func getCurrentIncentiveID() string {
	incentiveID := incentiveCounter.Get()

	return strconv.FormatInt(incentiveID, 10)
}

func nextIncentiveID() string {
	incentiveID := incentiveCounter.next()

	return strconv.FormatInt(incentiveID, 10)
}