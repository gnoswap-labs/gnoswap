package halt

import "gno.land/p/demo/ufmt"

var _ Operation = (*basicOperation)(nil)

// Operation represents a protocol operation that can be halted.
type Operation interface {
	Type() OpType
	Name() string
	Desc() string
}

// OpType represents the type of operation.
type OpType string

// Predefined operation types in the protocol.
const (
	OpTypeSwap       OpType = "swap"
	OpTypeLiquidity  OpType = "liquidity"
	OpTypeWithdraw   OpType = "withdraw"
	OpTypeGovernance OpType = "governance"
)

func (o OpType) String() string { return string(o) }

// OpTypeFromString converts a string to an `OpType`.
func OpTypeFromString(s string) (OpType, error) {
	switch s {
	case "swap":
		return OpTypeSwap, nil
	case "liquidity":
		return OpTypeLiquidity, nil
	case "withdraw":
		return OpTypeWithdraw, nil
	case "governance":
		return OpTypeGovernance, nil
	default:
		return "", ufmt.Errorf("invalid operation type: %s", s)
	}
}

// basicOperation implements the `Operation` interface.
type basicOperation struct {
	baseInfo
	opType OpType
}

func (o basicOperation) Type() OpType { return o.opType }

// newOperation creates a new `BasicOperation` instance.
func newOperation(opType OpType, name, desc string) Operation {
	return basicOperation{newBaseInfo(name, desc), opType}
}
