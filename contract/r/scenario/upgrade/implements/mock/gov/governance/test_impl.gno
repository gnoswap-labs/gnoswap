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
	return t.instance.ProposeText(title, description)
}

func (t *TestGovernance) ProposeCommunityPoolSpend(title string, description string, to address, tokenPath string, amount int64) int64 {
	return t.instance.ProposeCommunityPoolSpend(title, description, to, tokenPath, amount)
}

func (t *TestGovernance) ProposeParameterChange(title string, description string, numToExecute int64, executions string) int64 {
	return t.instance.ProposeParameterChange(title, description, numToExecute, executions)
}

func (t *TestGovernance) Vote(proposalId int64, yes bool) string {
	return t.instance.Vote(proposalId, yes)
}

func (t *TestGovernance) Execute(proposalId int64) int64 {
	return t.instance.Execute(proposalId)
}

func (t *TestGovernance) Cancel(proposalId int64) int64 {
	return t.instance.Cancel(proposalId)
}

func (t *TestGovernance) Reconfigure(votingStartDelay int64, votingPeriod int64, votingWeightSmoothingDuration int64, quorum int64, proposalCreationThreshold int64, executionDelay int64, executionWindow int64) int64 {
	return t.instance.Reconfigure(votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow)
}

// IGovernanceGetter interface - Store data getters
func (t *TestGovernance) GetLatestConfigVersion() int64 {
	return t.instance.GetLatestConfigVersion()
}

func (t *TestGovernance) GetCurrentProposalID() int64 {
	return t.instance.GetCurrentProposalID()
}

func (t *TestGovernance) GetMaxSmoothingPeriod() int64 {
	return t.instance.GetMaxSmoothingPeriod()
}

// Config getters
func (t *TestGovernance) GetLatestConfig() governance.Config {
	return t.instance.GetLatestConfig()
}

func (t *TestGovernance) GetConfig(configVersion int64) (governance.Config, error) {
	return t.instance.GetConfig(configVersion)
}

// Proposal getters
func (t *TestGovernance) GetProposalCount() int {
	return t.instance.GetProposalCount()
}

func (t *TestGovernance) GetProposalIDs(offset, count int) []int64 {
	return t.instance.GetProposalIDs(offset, count)
}

func (t *TestGovernance) ExistsProposal(proposalID int64) bool {
	return t.instance.ExistsProposal(proposalID)
}

func (t *TestGovernance) GetProposal(proposalID int64) (*governance.Proposal, error) {
	return t.instance.GetProposal(proposalID)
}

func (t *TestGovernance) GetProposerByProposalId(proposalId int64) (address, error) {
	return t.instance.GetProposerByProposalId(proposalId)
}

func (t *TestGovernance) GetProposalTypeByProposalId(proposalId int64) (governance.ProposalType, error) {
	return t.instance.GetProposalTypeByProposalId(proposalId)
}

func (t *TestGovernance) GetYeaByProposalId(proposalId int64) (int64, error) {
	return t.instance.GetYeaByProposalId(proposalId)
}

func (t *TestGovernance) GetNayByProposalId(proposalId int64) (int64, error) {
	return t.instance.GetNayByProposalId(proposalId)
}

func (t *TestGovernance) GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	return t.instance.GetConfigVersionByProposalId(proposalId)
}

func (t *TestGovernance) GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	return t.instance.GetQuorumAmountByProposalId(proposalId)
}

func (t *TestGovernance) GetTitleByProposalId(proposalId int64) (string, error) {
	return t.instance.GetTitleByProposalId(proposalId)
}

func (t *TestGovernance) GetDescriptionByProposalId(proposalId int64) (string, error) {
	return t.instance.GetDescriptionByProposalId(proposalId)
}

func (t *TestGovernance) GetProposalStatusByProposalId(proposalId int64) (string, error) {
	return t.instance.GetProposalStatusByProposalId(proposalId)
}

// Vote getters
func (t *TestGovernance) GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	return t.instance.GetVoteStatus(proposalId)
}

func (t *TestGovernance) GetVotingInfoCount(proposalID int64) int {
	return t.instance.GetVotingInfoCount(proposalID)
}

func (t *TestGovernance) GetVotingInfoAddresses(proposalID int64, offset, count int) []address {
	return t.instance.GetVotingInfoAddresses(proposalID, offset, count)
}

func (t *TestGovernance) ExistsVotingInfo(proposalID int64, addr address) bool {
	return t.instance.ExistsVotingInfo(proposalID, addr)
}

func (t *TestGovernance) GetVotingInfo(proposalID int64, addr address) (*governance.VotingInfo, error) {
	return t.instance.GetVotingInfo(proposalID, addr)
}

func (t *TestGovernance) GetVoteWeight(proposalID int64, addr address) (int64, error) {
	return t.instance.GetVoteWeight(proposalID, addr)
}

func (t *TestGovernance) GetVotedHeight(proposalID int64, addr address) (int64, error) {
	return t.instance.GetVotedHeight(proposalID, addr)
}

func (t *TestGovernance) GetVotedAt(proposalID int64, addr address) (int64, error) {
	return t.instance.GetVotedAt(proposalID, addr)
}

// User proposal getters
func (t *TestGovernance) GetUserProposalCount(user address) int {
	return t.instance.GetUserProposalCount(user)
}

func (t *TestGovernance) GetUserProposalIDs(user address, offset, count int) []int64 {
	return t.instance.GetUserProposalIDs(user, offset, count)
}

// Active proposal query
func (t *TestGovernance) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return t.instance.GetOldestActiveProposalSnapshotTime()
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
