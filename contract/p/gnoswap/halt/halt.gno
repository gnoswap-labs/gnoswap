package halt

var _ Operation = (*basicOperation)(nil)

const (
	rawSwap       = "swap"
	rawLiquidity  = "liquidity"
	rawWithdraw   = "withdraw"
	rawGovernance = "governance"
)

// Operation represents a protocol operation that can be halted.
type Operation interface {
	baseOp
	Type() OpType
}

// OpType represents the type of operation.
type OpType string

// Predefined operation types in the protocol.
const (
	OpTypePool       OpType = "pool"
	OpTypePosition   OpType = "position"
	OpTypeProtocolFee OpType = "protocol_fee"
	OpTypeRouter     OpType = "router"
	OpTypeStaker     OpType = "staker"
	OpTypeLaunchpad  OpType = "launchpad"
	OpTypeGovernance OpType = rawGovernance

	OpTypeWithdraw OpType = rawWithdraw
	OpTypeDeposit OpType = "deposit"
	OpTypeSwap OpType = rawSwap
	OpTypeLiquidity = rawLiquidity
)

func (o OpType) String() string { return string(o) }

// basicOperation implements the `Operation` interface.
type basicOperation struct {
	baseInfo
	opType OpType
}

func (o basicOperation) Type() OpType { return o.opType }

// NewOperation creates a new `BasicOperation` instance.
func NewOperation(opType OpType, name, desc string) Operation {
	return basicOperation{newBaseInfo(name, desc), opType}
}
