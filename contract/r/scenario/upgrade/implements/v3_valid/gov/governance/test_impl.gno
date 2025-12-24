// Simplified test implementation for gov/governance contract upgrade testing
package v3_valid

import (
	"gno.land/r/gnoswap/gov/governance"
	v1 "gno.land/r/gnoswap/gov/governance/v1"
)

func NewV3ValidGovernance(store governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
	return &TestGovernance{
		instance: v1.NewGovernanceV1(store, stakerAccessor),
	}
}

func init() {
	governance.RegisterInitializer(cross, func(store governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
		return NewV3ValidGovernance(store, stakerAccessor)
	})
}

// TestGovernance is a minimal test implementation that delegates to v1
type TestGovernance struct {
	instance governance.IGovernance
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

// IGovernanceApi interface
func (t *TestGovernance) GetProposerByProposalId(id int64) string {
	return t.instance.GetProposerByProposalId(id)
}

func (t *TestGovernance) GetProposalTypeByProposalId(id int64) string {
	return t.instance.GetProposalTypeByProposalId(id)
}

func (t *TestGovernance) GetYeaByProposalId(id int64) int64 {
	return t.instance.GetYeaByProposalId(id)
}

func (t *TestGovernance) GetNayByProposalId(id int64) int64 {
	return t.instance.GetNayByProposalId(id)
}

func (t *TestGovernance) GetProposalById(id int64) string {
	return t.instance.GetProposalById(id)
}

func (t *TestGovernance) GetVoteStatusFromProposalById(id int64) string {
	return t.instance.GetVoteStatusFromProposalById(id)
}

func (t *TestGovernance) GetVoteByAddressFromProposalById(addr address, id int64) string {
	return t.instance.GetVoteByAddressFromProposalById(addr, id)
}

func (t *TestGovernance) GetConfigVersionByProposalId(id int64) int64 {
	return t.instance.GetConfigVersionByProposalId(id)
}

func (t *TestGovernance) GetQuorumAmountByProposalId(id int64) int64 {
	return t.instance.GetQuorumAmountByProposalId(id)
}

func (t *TestGovernance) GetTitleByProposalId(id int64) string {
	return t.instance.GetTitleByProposalId(id)
}

func (t *TestGovernance) GetDescriptionByProposalId(id int64) string {
	return t.instance.GetDescriptionByProposalId(id)
}

func (t *TestGovernance) GetExecutionStateByProposalId(id int64) string {
	return t.instance.GetExecutionStateByProposalId(id)
}

func (t *TestGovernance) GetLatestConfig() governance.Config {
	return t.instance.GetLatestConfig()
}

func (t *TestGovernance) GetConfig(configVersion int64) governance.Config {
	return t.instance.GetConfig(configVersion)
}

// IVoteApi interface
func (t *TestGovernance) GetVoteWeight(proposalID int64, address address) int64 {
	return t.instance.GetVoteWeight(proposalID, address)
}

func (t *TestGovernance) GetVotedHeight(proposalID int64, address address) int64 {
	return t.instance.GetVotedHeight(proposalID, address)
}

func (t *TestGovernance) GetVotedAt(proposalID int64, address address) int64 {
	return t.instance.GetVotedAt(proposalID, address)
}

func (t *TestGovernance) GetMaxSmoothingPeriod() int64 {
	return t.instance.GetMaxSmoothingPeriod()
}

func (t *TestGovernance) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return t.instance.GetOldestActiveProposalSnapshotTime()
}
