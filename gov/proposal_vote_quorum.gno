package gov

var _ ProposalData = (*ProposalDataGovParameterVoteQuorum)(nil)

type ProposalDataGovParameterVoteQuorum struct {
	NewVoteQuorumNumerator bigint
	NewVoteQuorumDenominator bigint
}

func (p ProposalDataGovParameterVoteQuorum) ProposalType() ProposalType {
	return ProposalTypeGovParameterVoteQuorum
}

func (p ProposalDataGovParameterVoteQuorum) isProposalData() {}

func (p ProposalDataGovParameterVoteQuorum) isValid() bool {
	return p.NewVoteQuorumNumerator > 0 && p.NewVoteQuorumDenominator > 0
}

func (p ProposalDataGovParameterVoteQuorum) execute() error {
	setVoteQuorum(p.NewVoteQuorumNumerator, p.NewVoteQuorumDenominator)
	return nil
}