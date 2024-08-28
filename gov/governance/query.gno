package governance

import (
	"std"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// parseCallsFromJSON converts a JSON array of calls into a slice of Call structs.
// The input JSON should be an array of objects, each representing a single call.
//
// Example JSON input:
// [
//
//	{
//	  "to": "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5",
//	  "selector": 1,
//	  "calldata": "test_data"
//	},
//	{
//	  "to": "g1sss7jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
//	  "selector": 2,
//	  "calldata": "more_test_data"
//	}
//
// ]
//
// Returns a slice of Call structs.
func parseCallsFromJSON(node *json.Node) []Call {
	if !node.IsArray() {
		panic(ufmt.Errorf("calls must be an array"))
	}

	var calls []Call
	// iterate over each element in the array
	node.ArrayEach(func(i int, callNode *json.Node) {
		// parse each call object
		call := parseCall(callNode)
		calls = append(calls, call)
	})

	return calls
}

// parseCall converts a single JSON object representing a call into a Call struct.
// The input JSON object should have the following structure:
//
//	{
//	  "to": "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5",
//	  "selector": 1,
//	  "calldata": "test_data"
//	}
//
// Returns a Call struct.
func parseCall(node *json.Node) Call {
	if !node.IsObject() {
		panic(ufmt.Errorf("call must be an object"))
	}

	var call Call
	var err error

	// parse `to` field: must be string type representing an address
	toNode := node.MustKey("to")
	if !toNode.IsString() {
		panic(ufmt.Errorf("'to' must be a string"))
	}
	call.To = std.Address(toNode.MustString())

	// parse `selector` field: must be a number type
	selectorNode := node.MustKey("selector")
	if !selectorNode.IsNumber() {
		panic(ufmt.Errorf("'selector' must be a number"))
	}

	// parse `calldata` field: must be a string type, will be coneverted to a byte slice
	calldataNode := node.MustKey("calldata")
	if !calldataNode.IsString() {
		panic(ufmt.Errorf("'calldata' must be a string"))
	}
	calldataStr := calldataNode.MustString()
	call.Calldata = calldataStr

	return call
}

func parseUint64Field(node *json.Node, key string) uint64 {
	fieldName := node.MustKey(key)
	if !fieldName.IsNumber() {
		panic(ufmt.Sprintf("'%s' must be a number", key))
	}
	return parseUint(fieldName.String(), 10, 64)
}

func parseStringField(node *json.Node, key string) string {
	fieldName := node.MustKey(key)
	if !fieldName.IsString() {
		panic(ufmt.Sprintf("'%s' must be a string", key))
	}
	return fieldName.String()
}
