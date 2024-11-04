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

func GetMaxVotingWeight(timestamp uint64) uint64 {
	if timestamp > uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	totalWeight := uint64(0)

	for _, history := range delegationModifiedHistory {
		for _, record := range history {
			if record.delegatedTimestamp > timestamp {
				continue
			}

			totalWeight += record.delegatedAmount - record.undelegatedAmount
		}
	}

	return totalWeight
}

// GetPossibleVotingAddressWithWeight returns the max voting weight + and possible voting address with weight
func GetPossibleVotingAddressWithWeight(endTimestamp uint64) (uint64, map[std.Address]uint64) {
	en.MintAndDistributeGns()
	calculateReward()

	if endTimestamp > uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	totalWeight := uint64(0)
	addressWithWeight := make(map[std.Address]uint64)

	for to, history := range delegationModifiedHistory {
		toWeight := uint64(0)

		for _, record := range history {
			if record.delegatedTimestamp > endTimestamp {
				continue
			}
			totalWeight += record.delegatedAmount - record.undelegatedAmount
			toWeight += record.delegatedAmount - record.undelegatedAmount
		}

		addressWithWeight[to] = toWeight
	}

	return totalWeight, addressWithWeight
}

// GetPossibleVotingAddressWithWeightJSON returns the max voting weight + and possible voting address with weight(string json format)
func GetPossibleVotingAddressWithWeightJSON(endTimestamp uint64) (uint64, string) {
	en.MintAndDistributeGns()
	calculateReward()

	if endTimestamp > uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	totalWeight := uint64(0)
	addressWithWeight := make(map[std.Address]uint64)

	for to, history := range delegationModifiedHistory {
		println("to", to.String())
		toWeight := uint64(0)

		for _, record := range history {
			if record.delegatedTimestamp > endTimestamp {
				continue
			}
			totalWeight += record.delegatedAmount - record.undelegatedAmount
			toWeight += record.delegatedAmount - record.undelegatedAmount
		}

		addressWithWeight[to] = toWeight
		println("toWeight", toWeight)
	}

	possibleObj := json.ObjectNode("", nil)
	possibleObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
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
