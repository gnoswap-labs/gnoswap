package render

import (
	"fmt"
	"strings"
	"unicode"
)

// ToAnchor converts a name to a valid HTML anchor ID.
// It converts to lowercase and replaces spaces with hyphens.
// Special characters are removed.
func ToAnchor(name string) string {
	var sb strings.Builder
	for _, r := range name {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			sb.WriteRune(unicode.ToLower(r))
		case r == ' ':
			sb.WriteRune('-')
		case r == '_' || r == '-':
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

// MethodAnchor creates an anchor for a method.
// Format: "typename.methodname" (both lowercase, pointer prefix stripped).
func MethodAnchor(typeName, methodName string) string {
	// Strip pointer prefix
	typeName = strings.TrimPrefix(typeName, "*")
	return ToAnchor(typeName) + "." + ToAnchor(methodName)
}

// AnchorRegistry tracks registered anchors to prevent collisions.
type AnchorRegistry struct {
	anchors map[string]int    // anchor -> count
	names   map[string]string // original name -> anchor
}

// NewAnchorRegistry creates a new anchor registry.
func NewAnchorRegistry() *AnchorRegistry {
	return &AnchorRegistry{
		anchors: make(map[string]int),
		names:   make(map[string]string),
	}
}

// Register registers an anchor and returns a unique version.
// If the anchor already exists, a numeric suffix is added.
func (r *AnchorRegistry) Register(anchor string) string {
	count, exists := r.anchors[anchor]
	if !exists {
		r.anchors[anchor] = 1
		return anchor
	}

	r.anchors[anchor] = count + 1
	return fmt.Sprintf("%s-%d", anchor, count)
}

// RegisterName converts a name to anchor and registers it.
// Returns the unique anchor for this name.
func (r *AnchorRegistry) RegisterName(name string) string {
	anchor := ToAnchor(name)
	unique := r.Register(anchor)
	r.names[name] = unique
	return unique
}

// Get returns the registered anchor for a name.
// Returns empty string if not registered.
func (r *AnchorRegistry) Get(name string) string {
	return r.names[name]
}
