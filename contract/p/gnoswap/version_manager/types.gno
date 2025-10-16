package version_manager

import "gno.land/p/nt/avl"

type VersionManager interface {
	RegisterInitializer(initializer func(store any) any) error
	ChangeImplementation(packagePath string) error

	GetDomainPath() string
	GetInitializers() *avl.Tree
	GetCurrentPackagePath() string
	GetCurrentImplementation() any
}
