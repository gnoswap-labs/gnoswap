package gov

import (
	"std"
	"fmt"
)


var parameters map[string]interface{}


func parameterKey(realm std.Realm, key string) string {
	return fmt.Sprintf("%s:%s", realm.Addr(), key)
}

// GetParameter returns the value of a parameter
func getParameter(realm std.Realm, key string) (interface{}, bool) {
	res, ok := parameters[parameterKey(realm, key)]
	return res, ok
}

// setParameter sets the value of a parameter
func setParameter(realm std.Realm, key string, value interface{}) {
	parameters[parameterKey(realm, key)] = value
}

func setGovParameter(key string, value interface{}) {
	govRealm := std.CurrentRealm() 
	setParameter(govRealm, key, value)
}

func GetParameter(key string) (interface{}, bool) {
	return getParameter(std.PrevRealm(), key)
}

func getGovParameter(key string) (interface{}, bool) {
	govRealm := std.CurrentRealm() 
	return getParameter(govRealm, key)
}

type ParameterChange struct {
	Key string
	Value interface{}
}

func setParameters(realm std.Realm, changes []ParameterChange) {
	for _, change := range changes {
		setParameter(realm, change.Key, change.Value)
	}
}

var _ ProposalData = ProposalParameterChange{}

type ProposalParameterChange struct {
	Realm std.Realm
	Changes []ParameterChange
}

func (p ProposalParameterChange) ProposalType() ProposalType {
	return ProposalTypeParameterChange
}

func (p ProposalParameterChange) isProposalData() {}

func (p ProposalParameterChange) execute() error {
	setParameters(p.Realm, p.Changes)

	return nil
}
