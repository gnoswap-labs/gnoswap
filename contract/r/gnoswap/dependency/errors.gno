package dependency

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	// General errors
	errInvalidContractName   = errors.New("invalid contract name")
	errInvalidVersion        = errors.New("invalid version")
	errInvalidDependency     = errors.New("invalid dependency")
	errContractNotRegistered = errors.New("contract not registered")
	errVersionNotFound       = errors.New("version not found")
	errDependencyNotFound    = errors.New("dependency not found")
	errFunctionNotFound      = errors.New("function not found")
	errInvalidAddress        = errors.New("invalid address")

	// Registration errors
	errDependencyAlreadyExists = errors.New("dependency already exists")
	errCannotRegisterSelfDep   = errors.New("cannot register self dependency")
	errCircularDependency      = errors.New("circular dependency detected")

	// Validation errors
	errIncompatibleVersion = errors.New("incompatible version")
	errDependencyMismatch  = errors.New("dependency version mismatch")
	errMissingDependency   = errors.New("missing required dependency")

	// Access control errors
	errCallerIsNotAdmin      = errors.New("caller is not admin")
	errCallerIsNotGovernance = errors.New("caller is not governance")
	errCallerIsNotAuthorized = errors.New("caller is not authorized")
)

// makeErrorWithDetails combines an error with additional details.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
