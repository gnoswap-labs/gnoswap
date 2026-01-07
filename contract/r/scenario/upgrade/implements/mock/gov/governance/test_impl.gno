// Simplified test implementation for gov/governance contract upgrade testing
package mock

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	governance "gno.land/r/gnoswap/gov/governance"
	v1 "gno.land/r/gnoswap/gov/governance/v1"
)

func NewV3ValidGovernance(store governance.IGovernanceStore) governance.IGovernance {
	instance := v1.NewGovernanceV1(store, newStakerAccessor())

	return &TestGovernance{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
	}
}

// TestGovernance is a minimal test implementation that delegates to v1
type TestGovernance struct {
	instance governance.IGovernance
	mockFns  map[string]func(args ...any) any
}

func (t *TestGovernance) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestGovernance) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IGovernanceManager interface
func (t *TestGovernance) ProposeText(title string, description string) int64 {
	return t.ExecuteFn(
		"ProposeText",
		t.instance.ProposeText, // actualFn
		title, description,     // args
	).(int64)
}

func (t *TestGovernance) ProposeCommunityPoolSpend(title string, description string, to address, tokenPath string, amount int64) int64 {
	return t.ExecuteFn(
		"ProposeCommunityPoolSpend",
		t.instance.ProposeCommunityPoolSpend,      // actualFn
		title, description, to, tokenPath, amount, // args
	).(int64)
}

func (t *TestGovernance) ProposeParameterChange(title string, description string, numToExecute int64, executions string) int64 {
	return t.ExecuteFn(
		"ProposeParameterChange",
		t.instance.ProposeParameterChange,            // actualFn
		title, description, numToExecute, executions, // args
	).(int64)
}

func (t *TestGovernance) Vote(proposalId int64, yes bool) string {
	return t.ExecuteFn(
		"Vote",
		t.instance.Vote, // actualFn
		proposalId, yes, // args
	).(string)
}

func (t *TestGovernance) Execute(proposalId int64) int64 {
	return t.ExecuteFn(
		"Execute",
		t.instance.Execute, // actualFn
		proposalId,         // args
	).(int64)
}

func (t *TestGovernance) Cancel(proposalId int64) int64 {
	return t.ExecuteFn(
		"Cancel",
		t.instance.Cancel, // actualFn
		proposalId,        // args
	).(int64)
}

func (t *TestGovernance) Reconfigure(votingStartDelay int64, votingPeriod int64, votingWeightSmoothingDuration int64, quorum int64, proposalCreationThreshold int64, executionDelay int64, executionWindow int64) int64 {
	return t.ExecuteFn(
		"Reconfigure",
		t.instance.Reconfigure,                                                                                                            // actualFn
		votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow, // args
	).(int64)
}

// IGovernanceApi interface
func (t *TestGovernance) GetProposerByProposalId(id int64) string {
	return t.ExecuteFn(
		"GetProposerByProposalId",
		t.instance.GetProposerByProposalId, // actualFn
		id,                                 // args
	).(string)
}

func (t *TestGovernance) GetProposalTypeByProposalId(id int64) string {
	return t.ExecuteFn(
		"GetProposalTypeByProposalId",
		t.instance.GetProposalTypeByProposalId, // actualFn
		id,                                     // args
	).(string)
}

func (t *TestGovernance) GetMaxSmoothingPeriod() int64 {
	return t.ExecuteFn(
		"GetMaxSmoothingPeriod",
		t.instance.GetMaxSmoothingPeriod, // actualFn
	).(int64)
}

func (t *TestGovernance) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return t.ExecuteFn(
		"GetOldestActiveProposalSnapshotTime",
		t.instance.GetOldestActiveProposalSnapshotTime, // actualFn
	).(int64), false
}

func (t *TestGovernance) GetYeaByProposalId(id int64) int64 {
	return t.ExecuteFn(
		"GetYeaByProposalId",
		t.instance.GetYeaByProposalId, // actualFn
		id,                            // args
	).(int64)
}

func (t *TestGovernance) GetNayByProposalId(id int64) int64 {
	return t.ExecuteFn(
		"GetNayByProposalId",
		t.instance.GetNayByProposalId, // actualFn
		id,                            // args
	).(int64)
}

func (t *TestGovernance) GetConfigVersionByProposalId(id int64) int64 {
	return t.ExecuteFn(
		"GetConfigVersionByProposalId",
		t.instance.GetConfigVersionByProposalId, // actualFn
		id,                                      // args
	).(int64)
}

func (t *TestGovernance) GetQuorumAmountByProposalId(id int64) int64 {
	return t.ExecuteFn(
		"GetQuorumAmountByProposalId",
		t.instance.GetQuorumAmountByProposalId, // actualFn
		id,                                     // args
	).(int64)
}

func (t *TestGovernance) GetTitleByProposalId(id int64) string {
	return t.ExecuteFn(
		"GetTitleByProposalId",
		t.instance.GetTitleByProposalId, // actualFn
		id,                              // args
	).(string)
}

func (t *TestGovernance) GetDescriptionByProposalId(id int64) string {
	return t.ExecuteFn(
		"GetDescriptionByProposalId",
		t.instance.GetDescriptionByProposalId, // actualFn
		id,                                    // args
	).(string)
}

func (t *TestGovernance) GetExecutionStateByProposalId(id int64) string {
	return t.ExecuteFn(
		"GetExecutionStateByProposalId",
		t.instance.GetExecutionStateByProposalId, // actualFn
		id,                                       // args
	).(string)
}

func (t *TestGovernance) GetLatestConfig() governance.Config {
	return t.ExecuteFn(
		"GetLatestConfig",
		t.instance.GetLatestConfig, // actualFn
	).(governance.Config)
}

func (t *TestGovernance) GetConfig(configVersion int64) governance.Config {
	return t.ExecuteFn(
		"GetConfig",
		t.instance.GetConfig, // actualFn
		configVersion,        // args
	).(governance.Config)
}

// IVoteApi interface
func (t *TestGovernance) GetVoteWeight(proposalID int64, address address) int64 {
	return t.ExecuteFn(
		"GetVoteWeight",
		t.instance.GetVoteWeight, // actualFn
		proposalID, address,      // args
	).(int64)
}

func (t *TestGovernance) GetVotedHeight(proposalID int64, address address) int64 {
	return t.ExecuteFn(
		"GetVotedHeight",
		t.instance.GetVotedHeight, // actualFn
		proposalID, address,       // args
	).(int64)
}

func (t *TestGovernance) GetVotedAt(proposalID int64, address address) int64 {
	return t.ExecuteFn(
		"GetVotedAt",
		t.instance.GetVotedAt, // actualFn
		proposalID, address,   // args
	).(int64)
}

func (t *TestGovernance) GetProposal(id int64) (*governance.Proposal, bool) {
	return t.instance.GetProposal(id)
}

func (t *TestGovernance) GetProposalVotingInfo(proposalID int64, addr address) (*governance.VotingInfo, bool) {
	return t.instance.GetProposalVotingInfo(proposalID, addr)
}

func (t *TestGovernance) GetCurrentProposalID() int64 {
	return t.instance.GetCurrentProposalID()
}

func (t *TestGovernance) GetCurrentConfigVersion() int64 {
	return t.instance.GetCurrentConfigVersion()
}

type stakerAccessor struct {
	userDelegationAmounts  map[address]*avl.Tree
	totalDelegationAmounts *avl.Tree
}

func (s *stakerAccessor) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	tree, ok := s.userDelegationAmounts[userAddr]
	if !ok {
		return 0, false
	}

	amount := int64(0)
	exists := false

	tree.ReverseIterate("0", ufmt.Sprintf("%d", snapshotTime), func(key string, value any) bool {
		amount = value.(int64)
		exists = true
		return true
	})

	return amount, exists
}

func (s *stakerAccessor) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	amount := int64(0)
	exists := false

	s.totalDelegationAmounts.ReverseIterate("0", ufmt.Sprintf("%d", snapshotTime), func(key string, value any) bool {
		amount = value.(int64)
		exists = true
		return true
	})

	return amount, exists
}

func newStakerAccessor() *stakerAccessor {
	return &stakerAccessor{
		userDelegationAmounts:  make(map[address]*avl.Tree),
		totalDelegationAmounts: avl.NewTree(),
	}
}
