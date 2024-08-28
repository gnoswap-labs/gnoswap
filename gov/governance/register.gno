package governance

import (
	"std"
	"strings"
)

// registry stores registered functions
var registry = make(map[string]CallFunction)

// RegisterFunction registers a function with the generated key
// This allows the governor to execute custom functions during proposal execution.
func RegisterFunction(fnName string, fn CallFunction) {
	key := std.PrevRealm().PkgPath() + ":" + fnName
	registry[key] = fn
}

// executeCall executes a single call
func executeCall(call Call) string {
	fn, exist := registry[call.Key]
	if !exist {
		panic("FUNCTION_NOT_REGISTERED")
	}

	args := strings.Split(call.Calldata, ",")

	result, err := fn(args...)
	if err != nil {
		panic("CALL_EXECUTION_FAILED: " + err.Error())
	}

	return string(result)
}
