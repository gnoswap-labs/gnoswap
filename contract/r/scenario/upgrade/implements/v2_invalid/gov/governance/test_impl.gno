// Simplified test implementation for gov/governance contract upgrade testing
package v2_invalid

import (
	"gno.land/r/gnoswap/gov/governance"
)

func init() {
	governance.RegisterInitializer(cross, func(store governance.IGovernanceStore) governance.IGovernance {
		return &TestGovernance{}
	})
}

// TestGovernance is a minimal test implementation that panics on all methods
type TestGovernance struct{}

// IGovernanceManager interface
func (t *TestGovernance) ProposeText(title string, description string) int64 {
	panic("test implementation: ProposeText not supported")
}

func (t *TestGovernance) ProposeCommunityPoolSpend(title string, description string, to address, tokenPath string, amount int64) int64 {
	panic("test implementation: ProposeCommunityPoolSpend not supported")
}

func (t *TestGovernance) ProposeParameterChange(title string, description string, numToExecute int64, executions string) int64 {
	panic("test implementation: ProposeParameterChange not supported")
}

func (t *TestGovernance) Vote(proposalId int64, yes bool) string {
	panic("test implementation: Vote not supported")
}

func (t *TestGovernance) Execute(proposalId int64) int64 {
	panic("test implementation: Execute not supported")
}

func (t *TestGovernance) Cancel(proposalId int64) int64 {
	panic("test implementation: Cancel not supported")
}

func (t *TestGovernance) Reconfigure(votingStartDelay int64, votingPeriod int64, votingWeightSmoothingDuration int64, quorum int64, proposalCreationThreshold int64, executionDelay int64, executionWindow int64) int64 {
	panic("test implementation: Reconfigure not supported")
}

// IGovernanceApi interface
func (t *TestGovernance) GetProposerByProposalId(id int64) string {
	panic("test implementation: GetProposerByProposalId not supported")
}

func (t *TestGovernance) GetProposalTypeByProposalId(id int64) string {
	panic("test implementation: GetProposalTypeByProposalId not supported")
}

func (t *TestGovernance) GetYeaByProposalId(id int64) int64 {
	panic("test implementation: GetYeaByProposalId not supported")
}

func (t *TestGovernance) GetNayByProposalId(id int64) int64 {
	panic("test implementation: GetNayByProposalId not supported")
}

func (t *TestGovernance) GetProposalById(id int64) string {
	panic("test implementation: GetProposalById not supported")
}

func (t *TestGovernance) GetVoteStatusFromProposalById(id int64) string {
	panic("test implementation: GetVoteStatusFromProposalById not supported")
}

func (t *TestGovernance) GetVoteByAddressFromProposalById(addr address, id int64) string {
	panic("test implementation: GetVoteByAddressFromProposalById not supported")
}

func (t *TestGovernance) GetConfigVersionByProposalId(id int64) int64 {
	panic("test implementation: GetConfigVersionByProposalId not supported")
}

func (t *TestGovernance) GetQuorumAmountByProposalId(id int64) int64 {
	panic("test implementation: GetQuorumAmountByProposalId not supported")
}

func (t *TestGovernance) GetTitleByProposalId(id int64) string {
	panic("test implementation: GetTitleByProposalId not supported")
}

func (t *TestGovernance) GetDescriptionByProposalId(id int64) string {
	panic("test implementation: GetDescriptionByProposalId not supported")
}

func (t *TestGovernance) GetExecutionStateByProposalId(id int64) string {
	panic("test implementation: GetExecutionStateByProposalId not supported")
}

func (t *TestGovernance) GetLatestConfig() governance.Config {
	panic("test implementation: GetLatestConfig not supported")
}

func (t *TestGovernance) GetConfig(configVersion int64) governance.Config {
	panic("test implementation: GetConfig not supported")
}

// IVoteApi interface
func (t *TestGovernance) GetVoteWeight(proposalID int64, address address) int64 {
	panic("test implementation: GetVoteWeight not supported")
}

func (t *TestGovernance) GetVotedHeight(proposalID int64, address address) int64 {
	panic("test implementation: GetVotedHeight not supported")
}

func (t *TestGovernance) GetVotedAt(proposalID int64, address address) int64 {
	panic("test implementation: GetVotedAt not supported")
}
