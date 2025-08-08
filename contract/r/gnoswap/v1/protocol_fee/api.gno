package protocol_fee

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

func ApiGetAccuTransferToGovStaker() string {
	distributedAmountList := protocolFeeState.accuToGovStaker
	if distributedAmountList == nil {
		return ""
	}

	return marshal(buildByAvlTree(distributedAmountList))
}

func ApiGetAccuTransferToDevOps() string {
	distributedAmountList := protocolFeeState.accuToDevOps
	if distributedAmountList == nil {
		return ""
	}

	return marshal(buildByAvlTree(distributedAmountList))
}

func ApiGetHistoryTransferToGovStaker() string {
	historyTransferList := distributedToGovStakerHistory()
	if historyTransferList == nil {
		return ""
	}

	return marshal(buildByAvlTree(historyTransferList))
}

func ApiGetHistoryTransferToDevOps() string {
	historyTransferList := distributedToDevOpsHistory()
	if historyTransferList == nil {
		return ""
	}
	return marshal(buildByAvlTree(historyTransferList))
}

func buildByAvlTree(tree *avl.Tree) *json.Node {
	data := json.Builder().
		WriteString("height", formatInt(std.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	tree.Iterate("", "", func(key string, value any) bool {
		if iv, ok := value.(int64); !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		} else {
			data.WriteString(key, formatInt(iv))
		}
		return false
	})

	return data.Node()
}

func formatUint(v uint64) string {
	return strconv.FormatUint(v, 10)
}

func formatInt64(v int64) string {
	return strconv.FormatInt(v, 10)
}

func formatInt(v int64) string {
	return strconv.FormatInt(v, 10)
}

func marshal(node *json.Node) string {
	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// ApiGetActualBalance returns all tokens with their current balances (recorded + unrecorded)
func ApiGetActualBalance() string {
	tokenMap := make(map[string]int64)

	// get all recorded tokens
	for token := range protocolFeeState.tokenListWithAmount {
		actualBalance := common.BalanceOf(token, protocolFeeAddr)
		tokenMap[token] = actualBalance
	}

	// only include tokens that are already recorded.
	// check for any tokens that have balance will requires
	// iterating through known tokens or having a registry.
	data := json.Builder().
		WriteString("height", formatInt(std.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token, balance := range tokenMap {
		data.WriteString(token, formatInt64(balance))
	}

	return marshal(data.Node())
}

// ApiGetRecordedBalance returns the recorded tokens and their amounts
func ApiGetRecordedBalance() string {
	tokenList := GetTokenListWithAmount()
	if tokenList == nil {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(std.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token, amount := range tokenList {
		data.WriteString(token, formatInt64(amount))
	}

	return marshal(data.Node())
}

// ApiGetUnrecordedBalance returns tokens with unrecorded balances
func ApiGetUnrecordedBalance() string {
	unrecordedMap := make(map[string]int64)

	// Check all recorded tokens for discrepancies
	for token, recordedAmount := range protocolFeeState.tokenListWithAmount {
		actualBalance := common.BalanceOf(token, protocolFeeAddr)
		if actualBalance > recordedAmount {
			unrecordedAmount := actualBalance - recordedAmount
			unrecordedMap[token] = unrecordedAmount
		}
	}

	data := json.Builder().
		WriteString("height", formatInt(std.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token, unrecordedBalance := range unrecordedMap {
		data.WriteString(token, formatInt64(unrecordedBalance))
	}

	return marshal(data.Node())
}
