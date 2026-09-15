package governance

// ProposalActionStatus tracks the execution and cancellation status of a proposal.
// This structure manages the action-related state including who performed actions and when.
type ProposalActionStatus struct {
	canceled       bool    // Whether the proposal has been canceled
	canceledAt     int64   // Timestamp when proposal was canceled
	canceledHeight int64   // Block height when proposal was canceled
	canceledBy     address // Who canceled the proposal

	executed       bool    // Whether the proposal has been executed
	executedAt     int64   // Timestamp when proposal was executed
	executedHeight int64   // Block height when proposal was executed
	executedBy     address // Who executed the proposal

	executable bool // Whether this proposal type supports execution
}

/* Getter methods */
// Canceled reports whether this proposal has been marked canceled.
//
// Returns:
//   - bool: true when cancellation has been recorded
func (p *ProposalActionStatus) Canceled() bool { return p.canceled }

// CanceledAt returns the timestamp recorded when the proposal was canceled.
//
// Returns:
//   - int64: cancellation timestamp, or zero when none has been recorded
func (p *ProposalActionStatus) CanceledAt() int64 { return p.canceledAt }

// CanceledHeight returns the block height recorded when the proposal was canceled.
//
// Returns:
//   - int64: cancellation block height, or zero when none has been recorded
func (p *ProposalActionStatus) CanceledHeight() int64 { return p.canceledHeight }

// Executed reports whether this proposal has been marked executed.
//
// Returns:
//   - bool: true when execution has been recorded
func (p *ProposalActionStatus) Executed() bool { return p.executed }

// ExecutedAt returns the timestamp recorded when the proposal was executed.
//
// Returns:
//   - int64: execution timestamp, or zero when none has been recorded
func (p *ProposalActionStatus) ExecutedAt() int64 { return p.executedAt }

// ExecutedHeight returns the block height recorded when the proposal was executed.
//
// Returns:
//   - int64: execution block height, or zero when none has been recorded
func (p *ProposalActionStatus) ExecutedHeight() int64 { return p.executedHeight }

// Executable reports whether this proposal type supports execution.
//
// Returns:
//   - bool: true when the proposal's action can be executed
func (p *ProposalActionStatus) Executable() bool { return p.executable }

/* Setter methods */
// SetCanceled records whether the proposal is canceled.
//
// Parameters:
//   - canceled: cancellation state to store
func (p *ProposalActionStatus) SetCanceled(canceled bool) {
	p.canceled = canceled
}

// SetCanceledAt records the timestamp associated with proposal cancellation.
//
// Parameters:
//   - canceledAt: cancellation timestamp to store
func (p *ProposalActionStatus) SetCanceledAt(canceledAt int64) {
	p.canceledAt = canceledAt
}

// SetCanceledHeight records the block height associated with proposal cancellation.
//
// Parameters:
//   - canceledHeight: cancellation block height to store
func (p *ProposalActionStatus) SetCanceledHeight(canceledHeight int64) {
	p.canceledHeight = canceledHeight
}

// SetCanceledBy records the address that canceled the proposal.
//
// Parameters:
//   - canceledBy: address of the actor that canceled the proposal
func (p *ProposalActionStatus) SetCanceledBy(canceledBy address) {
	p.canceledBy = canceledBy
}

// SetExecuted records whether the proposal is executed.
//
// Parameters:
//   - executed: execution state to store
func (p *ProposalActionStatus) SetExecuted(executed bool) {
	p.executed = executed
}

// SetExecutedAt records the timestamp associated with proposal execution.
//
// Parameters:
//   - executedAt: execution timestamp to store
func (p *ProposalActionStatus) SetExecutedAt(executedAt int64) {
	p.executedAt = executedAt
}

// SetExecutedHeight records the block height associated with proposal execution.
//
// Parameters:
//   - executedHeight: execution block height to store
func (p *ProposalActionStatus) SetExecutedHeight(executedHeight int64) {
	p.executedHeight = executedHeight
}

// SetExecutedBy records the address that executed the proposal.
//
// Parameters:
//   - executedBy: address of the actor that executed the proposal
func (p *ProposalActionStatus) SetExecutedBy(executedBy address) {
	p.executedBy = executedBy
}

// SetExecutable records whether this proposal type supports execution.
//
// Parameters:
//   - executable: execution capability to store for the proposal type
func (p *ProposalActionStatus) SetExecutable(executable bool) {
	p.executable = executable
}

// CanceledBy returns the address recorded as having canceled the proposal.
// The value is meaningful when Canceled() is true; before then it is the
// zero address unless a caller has explicitly stored another value.
//
// Returns:
//   - address: address recorded for the cancellation actor
func (p *ProposalActionStatus) CanceledBy() address {
	return p.canceledBy
}

// IsExecuted reports whether execution has been recorded for the proposal.
//
// Returns:
//   - bool: true when the proposal has been marked executed
func (p *ProposalActionStatus) IsExecuted() bool {
	return p.executed
}

// ExecutedBy returns the address recorded as having executed the proposal.
// The value is meaningful when IsExecuted() is true; before then it is the
// zero address unless a caller has explicitly stored another value.
//
// Returns:
//   - address: address recorded for the execution actor
func (p *ProposalActionStatus) ExecutedBy() address {
	return p.executedBy
}

// IsExecutable reports whether this proposal type can be executed.
//
// Returns:
//   - bool: true when execution is supported for the proposal type
func (p *ProposalActionStatus) IsExecutable() bool {
	return p.executable
}

// NewProposalActionStatus creates a new action status for a proposal.
// Initializes the status with default values and the executable flag.
//
// Parameters:
//   - executable: whether this proposal type can be executed
//
// Returns:
//   - *ProposalActionStatus: new action status instance
func NewProposalActionStatus(executable bool) *ProposalActionStatus {
	return &ProposalActionStatus{
		canceled:   false,      // Proposal starts as not canceled
		executed:   false,      // Proposal starts as not executed
		executable: executable, // Set based on proposal type
	}
}

// Clone creates a deep copy of the ProposalActionStatus, or nil when the
// receiver is nil.
//
// Returns:
//   - *ProposalActionStatus: independent copy of the status, or nil for a nil receiver
func (p *ProposalActionStatus) Clone() *ProposalActionStatus {
	if p == nil {
		return nil
	}

	return &ProposalActionStatus{
		canceled:       p.canceled,
		canceledAt:     p.canceledAt,
		canceledHeight: p.canceledHeight,
		canceledBy:     p.canceledBy,
		executed:       p.executed,
		executedAt:     p.executedAt,
		executedHeight: p.executedHeight,
		executedBy:     p.executedBy,
		executable:     p.executable,
	}
}
