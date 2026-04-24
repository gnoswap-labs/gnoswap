package model

import "strings"

// DocParam represents a function parameter or return value.
type DocParam struct {
	Name string
	Type string
}

// String returns the string representation of the parameter.
// Format: "name type" or just "type" if unnamed.
func (p DocParam) String() string {
	if p.Name == "" {
		return p.Type
	}
	return p.Name + " " + p.Type
}

// DocReceiver represents a method receiver.
type DocReceiver struct {
	Name string
	Type string
}

// String returns the string representation of the receiver.
// Format: "(name type)" or "(type)" if unnamed.
func (r DocReceiver) String() string {
	if r.Name == "" {
		return "(" + r.Type + ")"
	}
	return "(" + r.Name + " " + r.Type + ")"
}

// IsPointer reports whether the receiver is a pointer type.
func (r DocReceiver) IsPointer() bool {
	return strings.HasPrefix(r.Type, "*")
}
