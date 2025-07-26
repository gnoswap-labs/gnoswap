package governance

import (
	"encoding/base64"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// Iterates over an AVL tree and applies a callback function to each element
func iterTree(tree *avl.Tree, cb func(key string, value any) bool) {
	tree.Iterate("", "", cb)
}

// strToInt Converts a string to an integer, panics if conversion fails
func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err.Error())
	}

	return res
}

// Marshals a JSON node to a string, panics if marshalling fails
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// Encodes a string to base64
func b64Encode(data string) string {
	return string(base64.StdEncoding.EncodeToString([]byte(data)))
}

// Decodes a base64 string, panics if decoding fails
func b64Decode(data string) string {
	decoded, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		panic(err.Error())
	}
	return string(decoded)
}

// Formats an unsigned integer to a string
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

func parseInt64(s string) int64 {
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid int64 value: %s", s))
	}

	return num
}

func parseUint64(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid uint64 value: %s", s))
	}

	return num
}

// Formats a boolean to a string
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

// numberKind represents the type of number to parse
type numberKind int

const (
	kindInt numberKind = iota
	kindInt64
	kindUint64
)

// Parses a string to a number (int, int64, or uint64), panics if parsing fails
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

// Parses a string to a boolean, panics if parsing fails
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

// makeExecuteMessage creates a message to execute a function
// message format: <pkgPath>*EXE*<function>*EXE*<params>
func makeExecuteMessage(pkgPath, function string, params []string) string {
	messageParams := make([]string, 0)

	messageParams = append(messageParams, pkgPath)
	messageParams = append(messageParams, function)
	messageParams = append(messageParams, strings.Join(params, ","))

	return strings.Join(messageParams, parameterSeparator)
}

func parseMessage(msg string) (pkgPath string, function string, params []string, err error) {
	parts := strings.Split(msg, parameterSeparator)
	if len(parts) != 3 {
		return "", "", nil, errInvalidMessageFormat
	}

	return parts[0], parts[1], strings.Split(parts[2], ","), nil
}