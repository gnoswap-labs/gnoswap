package gov

const govRealm = "gno.land/r/gov"

var parameters map[string]interface{}

func init() {
	parameters = make(map[string]interface{})
}

func parameterKey(realm string, key string) string {
	return realm + ":" + key
}

// GetParameter returns the value of a parameter
func getParameter(realm string, key string) (interface{}, bool) {
	return parameters[parameterKey(realm, key)]
}

// setParameter sets the value of a parameter
func setParameter(realm string, key string, value interface{}) {
	parameters[parameterKey(realm, key)] = value
}

func setGovParameter(key string, value interface{}) {
	setParameter(govRealm, key, value)
}

func GetParameter(key string) (interface{}, bool) {
	return getParameter(std.PrevRealm(), key)
}

func getGovParameter(key string) (interface{}, bool) {
	return getParameter(govRealm, key)
}

type ParameterChange struct {
	Key string
	Value interface{}
}

func setParameters(realm string, changes []ParameterChange) {
	for _, change := range changes {
		setParameter(realm, change.Key, change.Value)
	}
}

type ProposalParameterChange struct {
	Realm string
	Changes []ParameterChange
}

func (p ProposalParameterChange) ProposalType() ProposalType {
	return ProposalTypeParameterChange
}

func (p ProposalParameterChange) isProposal() {}

func (p ProposalParameterChange) Execute() {
	setParameters(p.Realm, p.Changes)
}
