package governance

import (
	"errors"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"

	cp "gno.land/r/gnoswap/v1/community_pool"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"
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
// region: Execute

type ExecutionContext struct {
	ProposalId  uint64
	Now         uint64
	Config      *Config
	Proposal    *ProposalInfo
	WindowStart uint64
	WindowEnd   uint64
}

func Execute(proposalId uint64) error {
	ctx, err := prepareExecution(proposalId)
	if err != nil {
		panic(err)
	}

	if err := validateVotes(ctx.Proposal); err != nil {
		panic(err)
	}

	if err := validateCommunityPoolToken(ctx.Proposal); err != nil {
		panic(err)
	}

	registry := createParameterHandlers()
	if err := executeProposal(ctx, registry); err != nil {
		panic(err)
	}

	updateProposalState(ctx)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Execute",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"proposalId", strconv.Itoa(int(proposalId)),
	)

	return nil
}

func executeProposal(ctx *ExecutionContext, registry *ParameterRegistry) error {
	switch ctx.Proposal.ProposalType {
	case ParameterChange:
		return executeParameterChange(ctx.Proposal.Execution.Msgs, registry)
	default:
		return nil
	}
}

func executeParameterChange(msgs []string, registry *ParameterRegistry) error {
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

func createParameterHandlers() *ParameterRegistry {
	registry := NewParameterRegistry()

	// region: Common path
	registry.Register(consts.COMMON_PATH, "SetHalt", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		common.SetHalt(parseBool(params[0])) // halt
		return nil
	})

	// region: Community pool
	registry.Register(consts.COMMUNITY_POOL_PATH, "TransferToken", func(params []string) error {
		if err := hasDesiredParams(params, 3); err != nil {
			return err
		}
		cp.TransferToken(
			params[0],              // pkgPath
			std.Address(params[1]), // to
			parseUint64(params[2]), // amount
		)
		return nil
	})

	// region: Emission
	registry.Register(consts.EMISSION_PATH, "ChangeDistributionPct", func(params []string) error {
		if err := hasDesiredParams(params, 8); err != nil {
			return err
		}
		en.ChangeDistributionPct(
			parseInt(params[0]),    // target01
			parseUint64(params[1]), // pct01
			parseInt(params[2]),    // target02
			parseUint64(params[3]), // pct02
			parseInt(params[4]),    // target03
			parseUint64(params[5]), // pct03
			parseInt(params[6]),    // target04
			parseUint64(params[7]), // pct04
		)
		return nil
	})

	// region: GNS Path
	registry.Register(consts.GNS_PATH, "SetAvgBlockTimeInMs", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		gns.SetAvgBlockTimeInMs(int64(parseInt(params[0]))) // ms
		return nil
	})

	// region: Governance Path
	registry.Register(consts.GOV_GOVERNANCE_PATH, "Reconfigure", func(params []string) error {
		if err := hasDesiredParams(params, 7); err != nil {
			return err
		}
		reconfigure(
			parseUint64(params[0]), // votingStartDelay
			parseUint64(params[1]), // votingPeriod
			parseUint64(params[2]), // votingWeightSmoothingDuration
			parseUint64(params[3]), // quorum
			parseUint64(params[4]), // proposalCreationhold
			parseUint64(params[5]), // executionDelay
			parseUint64(params[6]), // executionWindow
		)
		return nil
	})

	// region: Pool Path
	registry.Register(consts.POOL_PATH, "SetFeeProtocol", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		pl.SetFeeProtocol(
			uint8(parseUint64(params[0])), // feeProtocol0
			uint8(parseUint64(params[1])), // feeProtocol1
		)
		return nil
	})

	registry.Register(consts.POOL_PATH, "SetPoolCreationFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pl.SetPoolCreationFee(parseUint64(params[0])) // fee
		return nil
	})

	registry.Register(consts.POOL_PATH, "SetWithdrawalFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pl.SetWithdrawalFee(parseUint64(params[0])) // fee
		return nil
	})

	// region: Protocol fee
	registry.Register(consts.PROTOCOL_FEE_PATH, "SetDevOpsPct", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pf.SetDevOpsPct(parseUint64(params[0])) // pct
		return nil
	})

	// region: Router
	registry.Register(consts.ROUTER_PATH, "SetSwapFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		rr.SetSwapFee(parseUint64(params[0])) // fee
		return nil
	})

	// region: Staker
	registry.Register(consts.STAKER_PATH, "SetDepositGnsAmount", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.SetDepositGnsAmount(parseUint64(params[0])) // amount
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetPoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.SetPoolTier(
			params[0],              // pool
			parseUint64(params[1]), // tier
		)
		return nil
	})

	registry.Register(consts.STAKER_PATH, "ChangePoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.ChangePoolTier(
			params[0],              // pool
			parseUint64(params[1]), // tier
		)
		return nil
	})

	registry.Register(consts.STAKER_PATH, "RemovePoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.RemovePoolTier(params[0]) // pool
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetUnstakingFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.SetUnstakingFee(parseUint64(params[0]))
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetWarmUp", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.SetWarmUp(
			int64(parseInt(params[0])), // percent
			int64(parseInt(params[1])), // block
		)
		return nil
	})

	return registry
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

	proposal, err := getProposal(proposalId)
	if err != nil {
		return nil, err
	}

	validator := validateProposalState(proposal)
	if err := checkProposalValidation(validator); err != nil {
		return nil, err
	}

	ctx, err := createExecutionContext(proposalId, proposal)
	if err != nil {
		return nil, err
	}

	return ctx, nil
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
		isTextProposal:    proposal.ProposalType == Text,
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

func validateVotes(pp *ProposalInfo) error {
	yea := pp.Yea.Unit64()
	nea := pp.Nay.Unit64()
	quorum := pp.QuorumAmount

	if yea < quorum {
		return ufmt.Errorf("quorum not met (yes(%d) < quorum(%d))", yea, quorum)
	}

	if yea < nea {
		return ufmt.Errorf("no majority (yes(%d) < no(%d))", yea, nea)
	}

	return nil
}

func updateProposalState(ctx *ExecutionContext) {
	ctx.Proposal.ExecutionState.Executed = true
	ctx.Proposal.ExecutionState.ExecutedAt = ctx.Now
	ctx.Proposal.ExecutionState.Upcoming = false
	ctx.Proposal.ExecutionState.Active = false
	proposals[ctx.ProposalId] = *ctx.Proposal
}

func validateCommunityPoolToken(pp *ProposalInfo) error {
	if pp.ProposalType != CommunityPoolSpend {
		return nil
	}

	registered := cp.GetRegisteredTokens()
	commPath := pp.CommunityPoolSpend.TokenPath
	if !contains(registered, commPath) {
		return ufmt.Errorf("token(%s) is not registered to community pool",
			commPath,
		)
	}

	return nil
}

func hasDesiredParams(params []string, expected int) error {
	if len(params) != expected {
		return ufmt.Errorf("invalid parameters for %s. expected %d but got %d", params, expected, len(params))
	}
	return nil
}
