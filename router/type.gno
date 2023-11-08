package router

import "std"

type SwapCallbackData struct {
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}

type SwapPaths map[int]string
type TokenPairs map[string][]string

type QuoterTarget struct {
	pct            int
	pctAmount      bigint
	targetPath     string
	resultRatioX96 bigint
}

type ByOutputRatioDesc []QuoterTarget

func (a ByOutputRatioDesc) Len() int           { return len(a) }
func (a ByOutputRatioDesc) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByOutputRatioDesc) Less(i, j int) bool { return a[i].resultRatioX96 > a[j].resultRatioX96 }

// RPC
type RpcRoute struct {
	SwapPct   int      `json:"swapPct"`
	NumPools  int      `json:"numPools"`
	SwapPaths []string `json:"swapPaths"`
}

type RpcReturnBestSwap struct {
	TotalRoutes     int        `json:"totalRoutes"`
	TotalPct        int        `json:"totalPct"`
	Possible        bool       `json:"possible"`
	SwapType        string     `json:"swapType"`
	AmountSpecified bigint     `json:"amountSpecified"`
	AmountResult    bigint     `json:"amountResult"`
	RpcRoutes       []RpcRoute `json:"rpcRoutes"`
}
