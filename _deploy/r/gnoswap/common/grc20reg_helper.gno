package common

import (
	"gno.land/p/demo/grc/grc20"
	"gno.land/r/demo/grc20reg"
)

func GetToken(path string) grc20.Teller {
	tokenGetter := grc20reg.MustGet(path) // if token is not registered, it will panic
	token := tokenGetter()
	return token.CallerTeller()
}
