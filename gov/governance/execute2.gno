package governance

import (
	"gno.land/p/demo/ufmt"
)

// TODO: private
type ParameterChange struct {
	PkgPath string
	Function string
	Params []string
}

type ExecutionContext struct {
	ProposalId uint64
	Now uint64
	Config *Config
}