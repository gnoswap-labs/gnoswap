package model

import "strings"

// DocFunc represents a function or method declaration.
type DocFunc struct {
	DocNode
	Params   []DocParam
	Results  []DocParam
	Receiver *DocReceiver
}

// IsMethod reports whether this is a method (has a receiver).
func (f DocFunc) IsMethod() bool {
	return f.Receiver != nil
}

// ReceiverType returns the receiver type if this is a method.
// Returns empty string for functions.
func (f DocFunc) ReceiverType() string {
	if f.Receiver == nil {
		return ""
	}
	return f.Receiver.Type
}

// FullSignature returns the full function signature.
// Format: "func (recv Type) Name(params) results"
func (f DocFunc) FullSignature() string {
	var sb strings.Builder
	sb.WriteString("func ")

	if f.Receiver != nil {
		sb.WriteString(f.Receiver.String())
		sb.WriteString(" ")
	}

	sb.WriteString(f.Name)
	sb.WriteString("(")

	for i, p := range f.Params {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(p.String())
	}
	sb.WriteString(")")

	if len(f.Results) == 0 {
		return sb.String()
	}

	sb.WriteString(" ")
	if len(f.Results) == 1 && f.Results[0].Name == "" {
		sb.WriteString(f.Results[0].Type)
	} else {
		sb.WriteString("(")
		for i, r := range f.Results {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(r.String())
		}
		sb.WriteString(")")
	}

	return sb.String()
}
