package v1

import (
	"chain/runtime"
	"strconv"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"

	"gno.land/r/gnoswap/common"
)

// ApiGetAccuTransferToGovStaker returns accumulated transfers to gov/staker as JSON.
func (pf *protocolFeeV1) ApiGetAccuTransferToGovStaker() string {
	distributedAmountList := pf.store.GetAccuToGovStaker()
	if distributedAmountList == nil {
		return ""
	}

	return marshal(buildByAvlTree(distributedAmountList))
}

// ApiGetAccuTransferToDevOps returns accumulated transfers to devOps as JSON.
func (pf *protocolFeeV1) ApiGetAccuTransferToDevOps() string {
	distributedAmountList := pf.store.GetAccuToDevOps()
	if distributedAmountList == nil {
		return ""
	}

	return marshal(buildByAvlTree(distributedAmountList))
}

// ApiGetHistoryTransferToGovStaker returns transfer history to gov/staker as JSON.
func (pf *protocolFeeV1) ApiGetHistoryTransferToGovStaker() string {
	historyTransferList := pf.store.GetDistributedToGovStakerHistory()
	if historyTransferList == nil {
		return ""
	}

	return marshal(buildByAvlTree(historyTransferList))
}

// ApiGetHistoryTransferToDevOps returns transfer history to devOps as JSON.
func (pf *protocolFeeV1) ApiGetHistoryTransferToDevOps() string {
	historyTransferList := pf.store.GetDistributedToDevOpsHistory()
	if historyTransferList == nil {
		return ""
	}
	return marshal(buildByAvlTree(historyTransferList))
}

// ApiGetActualBalance returns all tokens with their current balances (recorded + unrecorded)
func (pf *protocolFeeV1) ApiGetActualBalance() string {
	tokenList := pf.store.GetTokenListWithAmounts()
	if tokenList == nil || len(tokenList) == 0 {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(runtime.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token := range tokenList {
		actualBalance := common.BalanceOf(token, protocolFeeAddr)
		data.WriteString(token, formatInt(actualBalance))
	}

	return marshal(data.Node())
}

// ApiGetRecordedBalance returns the recorded tokens and their amounts
func (pf *protocolFeeV1) ApiGetRecordedBalance() string {
	tokenList := pf.store.GetTokenListWithAmounts()
	if tokenList == nil {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(runtime.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token, amount := range tokenList {
		data.WriteString(token, formatInt(amount))
	}

	return marshal(data.Node())
}

// ApiGetUnrecordedBalance returns tokens with unrecorded balances
func (pf *protocolFeeV1) ApiGetUnrecordedBalance() string {
	tokenList := pf.store.GetTokenListWithAmounts()
	if tokenList == nil || len(tokenList) == 0 {
		return ""
	}

	unrecordedMap := make(map[string]int64)

	// Check all recorded tokens for discrepancies
	for token, recordedAmount := range tokenList {
		actualBalance := common.BalanceOf(token, protocolFeeAddr)
		if actualBalance > recordedAmount {
			unrecordedAmount := actualBalance - recordedAmount
			unrecordedMap[token] = unrecordedAmount
		}
	}

	data := json.Builder().
		WriteString("height", formatInt(runtime.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix()))

	for token, unrecordedBalance := range unrecordedMap {
		data.WriteString(token, formatInt(unrecordedBalance))
	}

	return marshal(data.Node())
}

// buildByAvlTree builds a JSON node from AVL tree data.
func buildByAvlTree(tree *avl.Tree) *json.Node {
	data := json.Builder().
		WriteString("height", formatInt(runtime.ChainHeight())).
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

// formatInt formats int64 to string.
func formatInt(v int64) string {
	return strconv.FormatInt(v, 10)
}

// marshal converts JSON node to string.
func marshal(node *json.Node) string {
	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
