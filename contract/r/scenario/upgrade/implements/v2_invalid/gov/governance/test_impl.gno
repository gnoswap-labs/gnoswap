// Simplified test implementation for gov/governance contract upgrade testing
package v2_invalid

import (
	governance "gno.land/r/gnoswap/gov/governance"
	v1 "gno.land/r/gnoswap/gov/governance/v1"
)

func NewV2InvalidGovernance(store governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
	instance := v1.NewGovernanceV1(store, stakerAccessor)

	return &TestGovernance{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	governance.RegisterInitializer(cross, func(store governance.IGovernanceStore, stakerAccessor governance.GovStakerAccessor) governance.IGovernance {
		return NewV2InvalidGovernance(store, stakerAccessor)
	})
}

// TestGovernance is a minimal test implementation that delegates to v1 only when method is activated
type TestGovernance struct {
	instance      governance.IGovernance
	activeMethods map[string]bool
}

func (t *TestGovernance) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestGovernance) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IGovernanceManager interface
func (t *TestGovernance) ProposeText(title string, description string) int64 {
	if !t.isActive("ProposeText") {
		panic("test implementation: ProposeText not supported")
	}
	return t.instance.ProposeText(title, description)
}

func (t *TestGovernance) ProposeCommunityPoolSpend(title string, description string, to address, tokenPath string, amount int64) int64 {
	if !t.isActive("ProposeCommunityPoolSpend") {
		panic("test implementation: ProposeCommunityPoolSpend not supported")
	}
	return t.instance.ProposeCommunityPoolSpend(title, description, to, tokenPath, amount)
}

func (t *TestGovernance) ProposeParameterChange(title string, description string, numToExecute int64, executions string) int64 {
	if !t.isActive("ProposeParameterChange") {
		panic("test implementation: ProposeParameterChange not supported")
	}
	return t.instance.ProposeParameterChange(title, description, numToExecute, executions)
}

func (t *TestGovernance) Vote(proposalId int64, yes bool) string {
	if !t.isActive("Vote") {
		panic("test implementation: Vote not supported")
	}
	return t.instance.Vote(proposalId, yes)
}

func (t *TestGovernance) Execute(proposalId int64) int64 {
	if !t.isActive("Execute") {
		panic("test implementation: Execute not supported")
	}
	return t.instance.Execute(proposalId)
}

func (t *TestGovernance) Cancel(proposalId int64) int64 {
	if !t.isActive("Cancel") {
		panic("test implementation: Cancel not supported")
	}
	return t.instance.Cancel(proposalId)
}

func (t *TestGovernance) Reconfigure(votingStartDelay int64, votingPeriod int64, votingWeightSmoothingDuration int64, quorum int64, proposalCreationThreshold int64, executionDelay int64, executionWindow int64) int64 {
	if !t.isActive("Reconfigure") {
		panic("test implementation: Reconfigure not supported")
	}
	return t.instance.Reconfigure(votingStartDelay, votingPeriod, votingWeightSmoothingDuration, quorum, proposalCreationThreshold, executionDelay, executionWindow)
}

// IGovernanceApi interface
func (t *TestGovernance) GetProposerByProposalId(id int64) string {
	if !t.isActive("GetProposerByProposalId") {
		panic("test implementation: GetProposerByProposalId not supported")
	}
	return t.instance.GetProposerByProposalId(id)
}

func (t *TestGovernance) GetProposalTypeByProposalId(id int64) string {
	if !t.isActive("GetProposalTypeByProposalId") {
		panic("test implementation: GetProposalTypeByProposalId not supported")
	}
	return t.instance.GetProposalTypeByProposalId(id)
}

func (t *TestGovernance) GetYeaByProposalId(id int64) int64 {
	if !t.isActive("GetYeaByProposalId") {
		panic("test implementation: GetYeaByProposalId not supported")
	}
	return t.instance.GetYeaByProposalId(id)
}

func (t *TestGovernance) GetNayByProposalId(id int64) int64 {
	if !t.isActive("GetNayByProposalId") {
		panic("test implementation: GetNayByProposalId not supported")
	}
	return t.instance.GetNayByProposalId(id)
}

func (t *TestGovernance) GetProposalById(id int64) string {
	if !t.isActive("GetProposalById") {
		panic("test implementation: GetProposalById not supported")
	}
	return t.instance.GetProposalById(id)
}

func (t *TestGovernance) GetVoteStatusFromProposalById(id int64) string {
	if !t.isActive("GetVoteStatusFromProposalById") {
		panic("test implementation: GetVoteStatusFromProposalById not supported")
	}
	return t.instance.GetVoteStatusFromProposalById(id)
}

func (t *TestGovernance) GetVoteByAddressFromProposalById(addr address, id int64) string {
	if !t.isActive("GetVoteByAddressFromProposalById") {
		panic("test implementation: GetVoteByAddressFromProposalById not supported")
	}
	return t.instance.GetVoteByAddressFromProposalById(addr, id)
}

func (t *TestGovernance) GetConfigVersionByProposalId(id int64) int64 {
	if !t.isActive("GetConfigVersionByProposalId") {
		panic("test implementation: GetConfigVersionByProposalId not supported")
	}
	return t.instance.GetConfigVersionByProposalId(id)
}

func (t *TestGovernance) GetQuorumAmountByProposalId(id int64) int64 {
	if !t.isActive("GetQuorumAmountByProposalId") {
		panic("test implementation: GetQuorumAmountByProposalId not supported")
	}
	return t.instance.GetQuorumAmountByProposalId(id)
}

func (t *TestGovernance) GetTitleByProposalId(id int64) string {
	if !t.isActive("GetTitleByProposalId") {
		panic("test implementation: GetTitleByProposalId not supported")
	}
	return t.instance.GetTitleByProposalId(id)
}

func (t *TestGovernance) GetDescriptionByProposalId(id int64) string {
	if !t.isActive("GetDescriptionByProposalId") {
		panic("test implementation: GetDescriptionByProposalId not supported")
	}
	return t.instance.GetDescriptionByProposalId(id)
}

func (t *TestGovernance) GetExecutionStateByProposalId(id int64) string {
	if !t.isActive("GetExecutionStateByProposalId") {
		panic("test implementation: GetExecutionStateByProposalId not supported")
	}
	return t.instance.GetExecutionStateByProposalId(id)
}

func (t *TestGovernance) GetLatestConfig() governance.Config {
	if !t.isActive("GetLatestConfig") {
		panic("test implementation: GetLatestConfig not supported")
	}
	return t.instance.GetLatestConfig()
}

func (t *TestGovernance) GetConfig(configVersion int64) governance.Config {
	if !t.isActive("GetConfig") {
		panic("test implementation: GetConfig not supported")
	}
	return t.instance.GetConfig(configVersion)
}

// IVoteApi interface
func (t *TestGovernance) GetVoteWeight(proposalID int64, address address) int64 {
	if !t.isActive("GetVoteWeight") {
		panic("test implementation: GetVoteWeight not supported")
	}
	return t.instance.GetVoteWeight(proposalID, address)
}

func (t *TestGovernance) GetVotedHeight(proposalID int64, address address) int64 {
	if !t.isActive("GetVotedHeight") {
		panic("test implementation: GetVotedHeight not supported")
	}
	return t.instance.GetVotedHeight(proposalID, address)
}

func (t *TestGovernance) GetVotedAt(proposalID int64, address address) int64 {
	if !t.isActive("GetVotedAt") {
		panic("test implementation: GetVotedAt not supported")
	}
	return t.instance.GetVotedAt(proposalID, address)
}

func (t *TestGovernance) GetMaxSmoothingPeriod() int64 {
	if !t.isActive("GetMaxSmoothingPeriod") {
		panic("test implementation: GetMaxSmoothingPeriod not supported")
	}
	return t.instance.GetMaxSmoothingPeriod()
}

func (t *TestGovernance) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	if !t.isActive("GetOldestActiveProposalSnapshotTime") {
		panic("test implementation: GetOldestActiveProposalSnapshotTime not supported")
	}
	return t.instance.GetOldestActiveProposalSnapshotTime()
}
