package v1

import (
	"encoding/base64"
	"strconv"

	"gno.land/p/nt/ufmt"
)

// b64Encode encodes a string to base64.
func b64Encode(data string) string {
	return string(base64.StdEncoding.EncodeToString([]byte(data)))
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

// formatBool formats a boolean to a string.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}
