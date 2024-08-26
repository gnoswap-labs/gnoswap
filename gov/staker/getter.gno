package staker

import (
	"std"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/gns"
)

// GetTotalStaked returns the total aount of tokens staked in the contract.
func GetTotalStaked() uint64 {
	return gns.BalanceOf(a2u(std.CurrentRealm().Addr()))
}

// GetDelegationAmount returns the amount of tokens delegated to a given address.
func GetDelegationAmount(toAddr string) uint64 {
	return delegatedTo[toAddr]
}

// GetAllDelegations returns a JSON string of all delegations,
// with addresses as keys and amounts as values.
func GetAllDelegations() string {
	delegationsArray := json.ArrayNode("", nil)

	for from, toAmount := range delegatedFromTo {
		delegationObj := json.ObjectNode("", nil)
		delegationObj.AppendObject("from", json.StringNode("from", from))
		for to, amount := range toAmount {
			delegationObj.AppendObject("to", json.StringNode("to", to))
			delegationObj.AppendObject("amount", json.NumberNode("amount", float64(amount)))
		}
		delegationsArray.AppendArray(delegationObj)
	}

	b, err := json.Marshal(delegationsArray)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)
}
