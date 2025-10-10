package storage

import "errors"

var (
	errOnlyAccessibleFromGnoswapRealm = errors.New("only accessible from gnoswap realm")
	errNotAllowedRegisterNamespace    = errors.New("not allowed to register namespace")
	errInvalidNamespace               = errors.New("invalid namespace")
)
