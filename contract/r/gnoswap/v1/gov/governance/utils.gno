package governance

import (
	"encoding/base64"
	"strconv"
	"strings"

	"gno.land/p/nt/avl"

	"gno.land/p/onbloc/json"
	"gno.land/p/nt/ufmt"
)

// iterTree iterates over an AVL tree and applies a callback function to each element.
func iterTree(tree *avl.Tree, cb func(key string, value any) bool) {
	tree.Iterate("", "", cb)
}

// strToInt converts a string to an integer.
func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err.Error())
	}

	return res
}

// marshal marshals a JSON node to a string.
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// b64Encode encodes a string to base64.
func b64Encode(data string) string {
	return string(base64.StdEncoding.EncodeToString([]byte(data)))
}

// b64Decode decodes a base64 string.
func b64Decode(data string) string {
	decoded, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		panic(err.Error())
	}
	return string(decoded)
}

// formatInt formats an integer to a string.
func formatInt(v any) string {
	switch v := v.(type) {
	case int8:
		return strconv.FormatInt(int64(v), 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

// parseInt64 parses a string to int64.
func parseInt64(s string) int64 {
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid int64 value: %s", s))
	}

	return num
}

// parseUint64 parses a string to uint64.
func parseUint64(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid uint64 value: %s", s))
	}

	return num
}

// formatBool formats a boolean to a string.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

// numberKind represents the type of number to parse.
type numberKind int

const (
	kindInt numberKind = iota
	kindInt64
	kindUint64
)

// parseNumber parses a string to a number (int, int64, or uint64).
func parseNumber(s string, kind numberKind) any {
	switch kind {
	case kindInt:
		num, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid int value: %s", s))
		}
		return int(num)
	case kindInt64:
		num, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid int64 value: %s", s))
		}
		return num
	case kindUint64:
		num, err := strconv.ParseUint(s, 10, 64)
		if err != nil {
			panic(ufmt.Sprintf("invalid uint64 value: %s", s))
		}
		return num
	default:
		panic(ufmt.Sprintf("unsupported number kind: %v", kind))
	}
}

// parseBool parses a string to a boolean.
func parseBool(s string) bool {
	switch s {
	case "true":
		return true
	case "false":
		return false
	default:
		panic(ufmt.Sprintf("invalid bool value: %s", s))
	}
}

// makeExecuteMessage creates a message to execute a function.
// Message format: <pkgPath>*EXE*<function>*EXE*<params>.
func makeExecuteMessage(pkgPath, function string, params []string) string {
	messageParams := make([]string, 0)

	messageParams = append(messageParams, pkgPath)
	messageParams = append(messageParams, function)
	messageParams = append(messageParams, strings.Join(params, ","))

	return strings.Join(messageParams, parameterSeparator)
}

// parseMessage parses an execution message into its components.
func parseMessage(msg string) (pkgPath string, function string, params []string, err error) {
	parts := strings.Split(msg, parameterSeparator)
	if len(parts) != 3 {
		return "", "", nil, errInvalidMessageFormat
	}

	return parts[0], parts[1], strings.Split(parts[2], ","), nil
}
