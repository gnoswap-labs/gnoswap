package router

import (
	"std"
)

type SwapCallbackData struct {
	// poolPath string
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}

type SwapPaths map[int]string
type TokenPairs map[string][]string

type QuoterTarget struct {
	// totalAmount int    // 100 // neee this?
	pct            int    // 5%
	pctAmount      bigint // 5%
	targetPath     string // gno.land/r/foo,500,gno.land/r/qux
	outputRatioX96 bigint // 121324894654
}

type ByOutputRatioDesc []QuoterTarget

func (a ByOutputRatioDesc) Len() int           { return len(a) }
func (a ByOutputRatioDesc) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByOutputRatioDesc) Less(i, j int) bool { return a[i].outputRatioX96 > a[j].outputRatioX96 }
