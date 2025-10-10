package dependency

import (
	"std"

	"gno.land/p/nt/ufmt"
)

type RealmPath string

// String returns the string representation of the realm path.
func (rp RealmPath) String() string {
	return string(rp)
}

// IsValid returns true if the realm path is valid.
func (rp RealmPath) IsValid() bool {
	return rp != ""
}

// Version represents a contract version number.
type Version int

// String returns the string representation of the version.
func (v Version) String() string {
	return ufmt.Sprintf("%d", int(v))
}

// IsValid returns true if the version is valid (greater than 0).
func (v Version) IsValid() bool {
	return v > 0
}

// FunctionName represents the name of a function that can be called.
type FunctionName string

// String returns the string representation of the function name.
func (f FunctionName) String() string {
	return string(f)
}

// IsValid returns true if the function name is not empty.
func (f FunctionName) IsValid() bool {
	return f != ""
}

// FunctionHandler is a function that handles a specific contract function call.
// It receives the caller realm and arguments, and returns a result.
// The handler should panic on errors (following Gno conventions).
type FunctionHandler func(caller std.Realm, args ...interface{}) interface{}

// FunctionRegistration represents a registered function for a specific contract version.
type FunctionRegistration struct {
	RealmPath RealmPath       // Contract that owns this function
	Version   Version         // Version of the contract
	Function  FunctionName    // Name of the function
	Handler   FunctionHandler // Handler function that executes the actual logic
}

// String returns the string representation of the function registration.
func (fr FunctionRegistration) String() string {
	return ufmt.Sprintf("%s:v%d.%s", fr.RealmPath, fr.Version, fr.Function.String())
}

// IsValid returns true if the function registration is valid.
func (fr FunctionRegistration) IsValid() bool {
	return fr.RealmPath.IsValid() && fr.Version.IsValid() && fr.Function.IsValid() && fr.Handler != nil
}

// MakeKey returns a unique key for this function registration.
func (fr FunctionRegistration) MakeKey() string {
	return ufmt.Sprintf("%s:%d:%s", fr.RealmPath.String(), fr.Version, fr.Function.String())
}

// Dependency represents a single dependency of a contract.
type Dependency struct {
	RealmPath RealmPath // Name of the dependent contract
	Version   Version   // Required version of the dependent contract
}

// String returns the string representation of the dependency.
func (d Dependency) String() string {
	return ufmt.Sprintf("%s:v%d", d.RealmPath.String(), d.Version)
}

// IsValid returns true if the dependency is valid.
func (d Dependency) IsValid() bool {
	return d.RealmPath.IsValid() && d.Version.IsValid()
}

// DependencySet represents all dependencies of a specific contract version.
type DependencySet struct {
	RealmPath    RealmPath    // Name of the contract
	Version      Version      // Version of the contract
	Dependencies []Dependency // List of dependencies
}

// String returns the string representation of the dependency set.
func (ds DependencySet) String() string {
	deps := ""
	for i, dep := range ds.Dependencies {
		if i > 0 {
			deps += ", "
		}
		deps += dep.String()
	}
	return ufmt.Sprintf("%s:v%d depends on [%s]", ds.RealmPath.String(), ds.Version, deps)
}

// IsValid returns true if the dependency set is valid.
func (ds DependencySet) IsValid() bool {
	if !ds.RealmPath.IsValid() || !ds.Version.IsValid() {
		return false
	}

	for _, dep := range ds.Dependencies {
		if !dep.IsValid() {
			return false
		}
	}

	return true
}

// HasDependency returns true if the dependency set contains the specified dependency.
func (ds DependencySet) HasDependency(contract RealmPath) bool {
	for _, dep := range ds.Dependencies {
		if dep.RealmPath == contract {
			return true
		}
	}
	return false
}

// GetDependencyVersion returns the version of the specified dependency.
// Returns 0 if the dependency is not found.
func (ds DependencySet) GetDependencyVersion(contract RealmPath) Version {
	for _, dep := range ds.Dependencies {
		if dep.RealmPath == contract {
			return dep.Version
		}
	}
	return 0
}

// ContractVersionInfo stores contract version and realm information.
type ContractVersionInfo struct {
	RealmPath RealmPath // Contract name
	Version   Version   // Version number
	Realm     std.Realm // Realm address
}

// String returns the string representation of contract version info.
func (cvi ContractVersionInfo) String() string {
	return ufmt.Sprintf("%s:v%d@%s", cvi.RealmPath.String(), cvi.Version, cvi.Realm.Addr().String())
}

// IsValid returns true if the contract version info is valid.
func (cvi ContractVersionInfo) IsValid() bool {
	return cvi.RealmPath.IsValid() && cvi.Version.IsValid() && cvi.Realm.Addr().IsValid()
}
