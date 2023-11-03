package router

import (
	"std"
)

type SwapCallbackData struct {
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}

type SwapPaths map[int]string
type TokenPairs map[string][]string

type QuoterTarget struct {
	pct            int    // 5%
	pctAmount      bigint //
	targetPath     string // gno.land/r/foo,500,gno.land/r/qux
	resultRatioX96 bigint //
}

type ByOutputRatioDesc []QuoterTarget

func (a ByOutputRatioDesc) Len() int           { return len(a) }
func (a ByOutputRatioDesc) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByOutputRatioDesc) Less(i, j int) bool { return a[i].resultRatioX96 > a[j].resultRatioX96 }

type ByOutputRatioAsc []QuoterTarget

func (a ByOutputRatioAsc) Len() int           { return len(a) }
func (a ByOutputRatioAsc) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByOutputRatioAsc) Less(i, j int) bool { return a[i].resultRatioX96 < a[j].resultRatioX96 }
