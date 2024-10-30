package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v2/emission"
)

// GetDelegationHistoryByAddress gets the delegation/undelegation raw history for an address.
func GetDelegationHistoryByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	history, exist := delegationHistory[addr]
	if !exist || len(history) == 0 {
		return ""
	}

	historyObj := json.ObjectNode("", nil)
	historyObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	historyObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))

	historyArr := json.ArrayNode("history", nil)
	for _, record := range history {
		recordObj := json.ObjectNode("", nil)
		recordObj.AppendObject("to", json.StringNode("to", record.to.String()))
		recordObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", record.amount)))
		recordObj.AppendObject("timestamp", json.StringNode("timestamp", ufmt.Sprintf("%d", record.timestamp)))
		recordObj.AppendObject("add", json.StringNode("add", ufmt.Sprintf("%t", record.add)))
		historyArr.AppendArray(recordObj)
	}

	historyObj.AppendObject("delegationHistory", historyArr)

	return marshal(historyObj)
}

func GetModifiedDelegationHistoryByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	history, exist := delegationModifiedHistory[addr]
	if !exist || len(history) == 0 {
		return ""
	}

	historyObj := json.ObjectNode("", nil)
	historyObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	historyObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))

	historyArr := json.ArrayNode("history", nil)
	for _, record := range history {
		if record.to != addr {
			continue
		}

		recordObj := json.ObjectNode("", nil)
		recordObj.AppendObject("from", json.StringNode("from", record.from.String()))
		recordObj.AppendObject("to", json.StringNode("to", record.to.String()))
		recordObj.AppendObject("delegatedHeight", json.StringNode("delegatedHeight", ufmt.Sprintf("%d", record.delegatedHeight)))
		recordObj.AppendObject("delegatedTimestamp", json.StringNode("delegatedTimestamp", ufmt.Sprintf("%d", record.delegatedTimestamp)))
		recordObj.AppendObject("delegatedAmount", json.StringNode("delegatedAmount", ufmt.Sprintf("%d", record.delegatedAmount)))
		recordObj.AppendObject("undelegatedHeight", json.StringNode("undelegatedHeight", ufmt.Sprintf("%d", record.undelegatedHeight)))
		recordObj.AppendObject("undelegatedTimestamp", json.StringNode("undelegatedTimestamp", ufmt.Sprintf("%d", record.undelegatedTimestamp)))
		recordObj.AppendObject("undelegatedAmount", json.StringNode("undelegatedAmount", ufmt.Sprintf("%d", record.undelegatedAmount)))
		historyArr.AppendArray(recordObj)
	}

	historyObj.AppendObject("delegationModifiedHistory", historyArr)

	return marshal(historyObj)
}
