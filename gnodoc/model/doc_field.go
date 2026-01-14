package model

import (
	"reflect"
	"strings"
)

// DocField represents a struct or interface field.
type DocField struct {
	DocNode
	Type string
	Tag  string
}

// HasTag reports whether this field has a struct tag.
func (f DocField) HasTag() bool {
	return f.Tag != ""
}

// TagValue returns the value for the given tag key.
// Returns empty string if the tag key is not found.
func (f DocField) TagValue(key string) string {
	if f.Tag == "" {
		return ""
	}

	tag := reflect.StructTag(f.Tag)
	value := tag.Get(key)
	if value != "" {
		return value
	}

	// Fallback: manual parsing for tags without quotes around the whole tag
	// e.g., `json:"id" xml:"id"`
	parts := strings.Split(f.Tag, " ")
	for _, part := range parts {
		if strings.HasPrefix(part, key+":") {
			// Extract value between quotes
			idx := strings.Index(part, ":")
			if idx >= 0 {
				val := part[idx+1:]
				val = strings.Trim(val, "\"")
				return val
			}
		}
	}

	return ""
}
