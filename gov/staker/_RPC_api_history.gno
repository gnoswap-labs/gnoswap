package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func GetDelegationHistoryByAddress(addr string) string {
	history, exist := delegationHistory[std.Address(addr)]
	if !exist || len(history) == 0 {
		return ""
	}

	historyObj := json.ObjectNode("", nil)
	historyObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	historyObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))

	historyArr := json.ArrayNode("history", nil)
	for i, record := range history {
		recordObj := json.ObjectNode("", nil)
		recordObj.AppendObject("to", json.StringNode("to", record.to))
		recordObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", record.amount)))
		recordObj.AppendObject("timestamp", json.StringNode("timestamp", ufmt.Sprintf("%d", record.timestamp)))
		recordObj.AppendObject("add", json.StringNode("add", ufmt.Sprintf("%t", record.add)))
		historyArr.AppendArray(recordObj)
	}

	historyObj.AppendObject("delegationHistory", historyArr)

	b, err := json.Marshal(historyObj)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)
}
