package halt

import (
	"gno.land/p/demo/ufmt"
)

var (
	_ HaltLevel = (*BasicHaltLevel)(nil)
	_ HaltLevel = (*CompositeHaltLevel)(nil)
)

// allowedOps is a map that tracks which operation types are allowed.
type allowedOps map[OpType]bool

// HaltLevel represents a protocol halt level with its configuration.
// It defines what operations are allowed at a specific halt level.
type HaltLevel interface {
	Level() uint8
	Name() string
	Desc() string
	IsOperationAllowed(op Operation) bool
}

// BasicHaltLevel implements the `HaltLevel` interface.
type BasicHaltLevel struct {
	baseInfo
	level      uint8
	allowedOps allowedOps
}

func (h BasicHaltLevel) Level() uint8 { return h.level }

// IsOperationAllowed checks if a given operation is allowed at this halt level.
// Returns true if the operation type exists in allowedOps and is marked as allowed.
func (h BasicHaltLevel) IsOperationAllowed(op Operation) bool {
	allowed, exists := h.allowedOps[op.Type()]
	return allowed && exists
}

// NewHaltLevel creates a new HaltLevel instance with the specified configuration.
func NewHaltLevel(level uint8, name, desc string, allowedOps allowedOps) HaltLevel {
	return BasicHaltLevel{baseInfo{name, desc}, level, allowedOps}
}

// CompositeOp represents the type of operation to be performed
// when combining multiple halt levels.
type CompositeOp string

// Available composite operations.
// TODO: add more operators if needed.
const (
	CompositeOpAnd CompositeOp = "and" // All conditions must be met
	CompositeOpOr  CompositeOp = "or"  // At least one condition must be met
)

// CompositeOpFromString converts a string to a CompositeOp.
// Returns an error if the string is not a valid operator.
func CompositeOpFromString(s string) (CompositeOp, error) {
	switch s {
	case "and":
		return CompositeOpAnd, nil
	case "or":
		return CompositeOpOr, nil
	default:
		return "", ufmt.Errorf("unknown composite operator: %s", s)
	}
}

func (o CompositeOp) String() string {
	return string(o)
}

// HaltLevels represents a collection of halt levels.
type HaltLevels []HaltLevel

// CompositeHaltLevel combines multiple halt levels with a logical operator.
type CompositeHaltLevel struct {
	baseInfo
	levels   HaltLevels
	operator CompositeOp
}

func (c *CompositeHaltLevel) Level() uint8 { return 0 /* Placeholder value */ }

// IsOperationAllowed checks if an operation is allowed based on the composite configuration.
//   - AND (CompositeOpAnd): all levels must allow the operation.
//   - OR (CompositeOpOr): at least one level must allow the operation.
func (c *CompositeHaltLevel) IsOperationAllowed(op Operation) bool {
	switch c.operator {
	case CompositeOpAnd:
		for _, level := range c.levels {
			if !level.IsOperationAllowed(op) {
				return false
			}
		}
		return true
	case CompositeOpOr:
		for _, level := range c.levels {
			if level.IsOperationAllowed(op) {
				return true
			}
		}
		return false
	default:
		return false
	}
}
