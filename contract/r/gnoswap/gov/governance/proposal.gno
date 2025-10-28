package governance

// ProposalType defines the different types of proposals supported by the governance system.
// Each type has different execution behavior and validation requirements.
type ProposalType string

const (
	Text               ProposalType = "TEXT"                 // Informational proposals for community discussion
	CommunityPoolSpend ProposalType = "COMMUNITY_POOL_SPEND" // Proposals to spend community pool funds
	ParameterChange    ProposalType = "PARAMETER_CHANGE"     // Proposals to modify system parameters
)

// String returns the human-readable string representation of the proposal type.
func (p ProposalType) String() string {
	switch p {
	case Text:
		return "Text"
	case CommunityPoolSpend:
		return "CommunityPoolSpend"
	case ParameterChange:
		return "ParameterChange"
	default:
		return "Unknown"
	}
}

// IsExecutable determines whether this proposal type can be executed.
// Text proposals are informational only and cannot be executed.
func (p ProposalType) IsExecutable() bool {
	switch p {
	case Text:
		return false
	case CommunityPoolSpend, ParameterChange:
		return true
	default:
		return false
	}
}
