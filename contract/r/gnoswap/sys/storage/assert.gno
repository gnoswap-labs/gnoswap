package storage

import (
	"chain/runtime"
	"strings"
)

func AssertIsOnlyAccessibleFromGnoswapRealm() {
	previousRealm := runtime.PreviousRealm()
	if previousRealm.IsUser() {
		panic(errOnlyAccessibleFromGnoswapRealm)
	}

	if previousRealm.PkgPath() != gnoswapNamespacePrefix {
		panic(errOnlyAccessibleFromGnoswapRealm)
	}
}

func AssertIsValidNamespace(namespace string) {
	if namespace == "" {
		panic(errInvalidNamespace)
	}

	if !strings.HasPrefix(namespace, gnoswapNamespacePrefix) {
		panic(errInvalidNamespace)
	}
}
