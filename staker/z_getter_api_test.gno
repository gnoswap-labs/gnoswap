package staker

import (
	"std"

	"strings"
	"encoding/base64"

	"testing"

	"gno.land/p/demo/avl"
)



func TestApiGetIncentivesInfo(t *testing.T) {
	tagii := ApiGetIncentivesInfo()
	// println(tagii)
}

func TestApiGetDepositsInfo(t *testing.T) {
	tagdi := ApiGetDepositsInfo()
	// println(tagdi)
}

func TestApiGetStakesInfo(t *testing.T) {
	tagsi := ApiGetStakesInfo()
	// println(tagsi)
}

func TestApiGetRewardInfo(t *testing.T) {
	tagri := ApiGetRewardInfo()
	// println(tagri)
}