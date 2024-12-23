package governance

import (
	"errors"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
)

var (
	errInvalidMessageFormat = errors.New("invalid message format")
	errProposalNotPassed    = errors.New("proposal has not passed")
)

const (
	EXECUTE_SEPARATOR = "*EXE*"
)

// Function signature for different parameter handlers
type ParameterHandler func([]string) error

// Registry for parameter handlers
type ParameterRegistry struct {
	handlers *avl.Tree
}

func NewParameterRegistry() *ParameterRegistry {
	return &ParameterRegistry{
		handlers: avl.NewTree(),
	}
}

func (r *ParameterRegistry) Register(
	pkgPath, function string,
	handler ParameterHandler,
) {
	key := makeHandlerKey(pkgPath, function)
	r.handlers.Set(key, handler)
}

func (r *ParameterRegistry) Handler(pkgPath, function string) (ParameterHandler, error) {
	key := makeHandlerKey(pkgPath, function)
	hdlr, exists := r.handlers.Get(key)
	if !exists {
		return nil, ufmt.Errorf("handler not found for %s", key)
	}
	return hdlr.(ParameterHandler), nil
}

func makeHandlerKey(pkgPath, function string) string {
	return ufmt.Sprintf("%s:%s", pkgPath, function)
}

///////////////////// EXECUTION /////////////////////

type ExecutionContext struct {
	ProposalId  uint64
	Now         uint64
	Config      *Config
	Proposal    *ProposalInfo
	WindowStart uint64
	WindowEnd   uint64
}

func Execute2(proposalId uint64) error {
	panic("todo")
}

func executeProposal(ctx *ExecutionContext, registry *ParameterRegistry) error {
	// TODO: change hard-code string value to enum
	if ctx.Proposal.ProposalType == "PARAMETER_CHANGE" {
		return executeParameterChange2(ctx.Proposal.Execution.Msgs, registry)
	}
	return nil
}

func executeParameterChange2(msgs []string, registry *ParameterRegistry) error {
	for _, msg := range msgs {
		pkgPath, function, params, err := parseMessage(msg)
		if err != nil {
			return err
		}

		handler, err := registry.Handler(pkgPath, function)
		if err != nil {
			return err
		}

		if err := handler(params); err != nil {
			return err
		}
	}

	return nil
}

func parseMessage(msg string) (pkgPath string, function string, params []string, err error) {
	parts := strings.Split(msg, EXECUTE_SEPARATOR)
	if len(parts) != 3 {
		return "", "", nil, errInvalidMessageFormat
	}

	return parts[0], parts[1], strings.Split(parts[2], ","), nil
}

///////////////////// VALIDATION /////////////////////

type ExecutionValidator struct {
	isTextProposal    bool
	isAlreadyExecuted bool
	isAlreadyCanceled bool
	isAlreadyRejected bool
	hasPassed         bool
}

func prepareExecution(proposalId uint64) (*ExecutionContext, error) {
	validateInitialState()

	panic("todo")
}

func validateInitialState() {
	common.IsHalted()

	en.MintAndDistributeGns()
	updateProposalsState()
}

func getProposal(proposalId uint64) (*ProposalInfo, error) {
	// TODO: change to avl API
	proposal, exists := proposals[proposalId]
	if !exists {
		return nil, ufmt.Errorf("proposal %d not found", proposalId)
	}

	return &proposal, nil
}

func validateProposalState(proposal *ProposalInfo) ExecutionValidator {
	return ExecutionValidator{
		isTextProposal:    proposal.ProposalType == "TEXT",
		isAlreadyExecuted: proposal.ExecutionState.Executed,
		isAlreadyCanceled: proposal.ExecutionState.Canceled,
		isAlreadyRejected: proposal.ExecutionState.Rejected,
		hasPassed:         proposal.ExecutionState.Passed,
	}
}

func checkProposalValidation(v ExecutionValidator) error {
	if v.isTextProposal {
		return errTextProposalNotExecutable
	}

	if v.isAlreadyExecuted || v.isAlreadyCanceled || v.isAlreadyRejected {
		return errors.New("proposal already executed, canceled, or rejected")
	}

	if !v.hasPassed {
		return errProposalNotPassed
	}

	return nil
}

func createExecutionContext(proposalId uint64, proposal *ProposalInfo) (*ExecutionContext, error) {
	now := uint64(time.Now().Unix())
	config := GetConfigVersion(proposal.ConfigVersion)

	votingEnd := calculateVotingEnd(proposal, &config)
	windowStart := calculateWindowStart(votingEnd, &config)
	windowEnd := calculateWindowEnd(windowStart, &config)

	if err := validateExecutionWindow(now, windowStart, windowEnd); err != nil {
		return nil, err
	}

	return &ExecutionContext{
		ProposalId:  proposalId,
		Now:         now,
		Config:      &config,
		Proposal:    proposal,
		WindowStart: windowStart,
		WindowEnd:   windowEnd,
	}, nil
}

func calculateVotingEnd(proposal *ProposalInfo, config *Config) uint64 {
	return proposal.ExecutionState.CreatedAt +
		config.VotingStartDelay +
		config.VotingPeriod
}

func calculateWindowStart(votingEnd uint64, config *Config) uint64 {
	return votingEnd + config.ExecutionDelay
}

func calculateWindowEnd(windowStart uint64, config *Config) uint64 {
	return windowStart + config.ExecutionWindow
}

func validateExecutionWindow(now, windowStart, windowEnd uint64) error {
	if now < windowStart {
		return ufmt.Errorf("execution window not started (now(%d) < windowStart(%d))", now, windowStart)
	}

	if now >= windowEnd {
		return ufmt.Errorf("execution window over (now(%d) >= windowEnd(%d))", now, windowEnd)
	}

	return nil
}
