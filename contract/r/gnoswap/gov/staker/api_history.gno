package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// GetPossibleVotingAddressWithWeight returns the max voting weight + and possible voting address with weight
func GetPossibleVotingAddressWithWeight(endTimestamp uint64) (uint64, map[std.Address]uint64) {
	if endTimestamp > uint64(time.Now().Unix()) {
		panic(addDetailToError(
			errFutureTime,
			ufmt.Sprintf("endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()),
		))
	}

	totalWeight := uint64(0)
	addressWithWeight := make(map[std.Address]uint64)

	delegationSnapShotHistory.Iterate("", "", func(key string, value interface{}) bool {
		history := value.([]DelegationSnapShotHistory)
		toAddr := std.Address(key)

		for i := len(history) - 1; i >= 0; i-- {
			record := history[i]

			if record.updatedAt > endTimestamp {
				continue
			}

			addressWithWeight[toAddr] = record.amount
			totalWeight += record.amount

			break
		}

		return false
	})

	return totalWeight, addressWithWeight
}

// GetPossibleVotingAddressWithWeightJSON returns the max voting weight + and possible voting address with weight(string json format)
func GetPossibleVotingAddressWithWeightJSON(endTimestamp uint64) (uint64, string) {
	totalWeight, addressWithWeight := GetPossibleVotingAddressWithWeight(endTimestamp)

	possibleObj := json.ObjectNode("", nil)
	possibleObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.ChainHeight())))
	possibleObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))

	possibleArr := json.ArrayNode("votingPower", nil)
	for to, weight := range addressWithWeight {
		addrWithWeightObj := json.ObjectNode("", nil)
		addrWithWeightObj.AppendObject("address", json.StringNode("address", to.String()))
		addrWithWeightObj.AppendObject("weight", json.StringNode("weight", ufmt.Sprintf("%d", weight)))
		possibleArr.AppendArray(addrWithWeightObj)
	}

	possibleObj.AppendObject("votingPower", possibleArr)

	return totalWeight, marshal(possibleObj)
}

// GetDelegationHistory retrieves the delegation history of a given caller address.
// It returns a JSON-formatted string containing the delegation records.
// Each record includes the delegated address, amount, timestamp, block height, and whether it was an addition or removal.
func GetDelegationHistory(caller std.Address) string {
	historyList := GetDelegateHistory(caller)
	historyRootNode := json.ObjectNode("", nil)
	historyArrNode := json.ArrayNode("delegationHistory", nil)
	for _, history := range historyList {
		historyObj := json.ObjectNode("", nil)
		historyObj.AppendObject("to", json.StringNode("to", history.to.String()))
		historyObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", history.amount)))
		historyObj.AppendObject("timestamp", json.StringNode("timestamp", ufmt.Sprintf("%d", history.timestamp)))
		historyObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", history.height)))
		historyObj.AppendObject("add", json.StringNode("add", ufmt.Sprintf("%t", history.add)))
		historyArrNode.AppendArray(historyObj)
	}
	historyRootNode.AppendObject("delegationHistory", historyArrNode)

	return marshal(historyRootNode)
}
