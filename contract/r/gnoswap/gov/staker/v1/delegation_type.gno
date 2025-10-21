package v1

// DelegationType represents the type of delegation action
type DelegationType string

// IsDelegate checks if this is a delegation action
func (dt DelegationType) IsDelegate() bool {
	return dt == DelegateType
}

// IsUndelegate checks if this is an undelegation action
func (dt DelegationType) IsUndelegate() bool {
	return dt == UnDelegateType
}