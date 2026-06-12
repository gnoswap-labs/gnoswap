package emission

import (
	"strconv"

	ufmt "gno.land/p/nt/ufmt/v0"
)

// formatInt converts various signed integer types to string representation.
// Panics if the type is not supported.
func formatInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}
