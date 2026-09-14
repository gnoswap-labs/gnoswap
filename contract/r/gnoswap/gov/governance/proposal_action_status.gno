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
func (p ProposalActionStatus) Canceled() bool        { return p.canceled }
func (p ProposalActionStatus) CanceledAt() int64     { return p.canceledAt }
func (p ProposalActionStatus) CanceledHeight() int64 { return p.canceledHeight }
func (p ProposalActionStatus) CanceledBy() address   { return p.canceledBy }
func (p ProposalActionStatus) Executed() bool        { return p.executed }
func (p ProposalActionStatus) ExecutedAt() int64     { return p.executedAt }
func (p ProposalActionStatus) ExecutedHeight() int64 { return p.executedHeight }
func (p ProposalActionStatus) ExecutedBy() address   { return p.executedBy }
func (p ProposalActionStatus) Executable() bool      { return p.executable }

// IsExecuted returns whether the proposal has been executed.
func (p ProposalActionStatus) IsExecuted() bool {
	return p.executed
}

// IsExecutable returns whether this proposal type can be executed.
func (p ProposalActionStatus) IsExecutable() bool {
	return p.executable
}

/* Functional updates */
func (p ProposalActionStatus) SetCanceled(canceled bool) ProposalActionStatus {
	p.canceled = canceled
	return p
}

func (p ProposalActionStatus) SetCanceledAt(canceledAt int64) ProposalActionStatus {
	p.canceledAt = canceledAt
	return p
}

func (p ProposalActionStatus) SetCanceledHeight(canceledHeight int64) ProposalActionStatus {
	p.canceledHeight = canceledHeight
	return p
}

func (p ProposalActionStatus) SetCanceledBy(canceledBy address) ProposalActionStatus {
	p.canceledBy = canceledBy
	return p
}

func (p ProposalActionStatus) SetExecuted(executed bool) ProposalActionStatus {
	p.executed = executed
	return p
}

func (p ProposalActionStatus) SetExecutedAt(executedAt int64) ProposalActionStatus {
	p.executedAt = executedAt
	return p
}

func (p ProposalActionStatus) SetExecutedHeight(executedHeight int64) ProposalActionStatus {
	p.executedHeight = executedHeight
	return p
}

func (p ProposalActionStatus) SetExecutedBy(executedBy address) ProposalActionStatus {
	p.executedBy = executedBy
	return p
}

func (p ProposalActionStatus) SetExecutable(executable bool) ProposalActionStatus {
	p.executable = executable
	return p
}

// MakeProposalActionStatus creates a new action status value with the
// executable flag.
func MakeProposalActionStatus(executable bool) ProposalActionStatus {
	return ProposalActionStatus{
		executable: executable,
	}
}
