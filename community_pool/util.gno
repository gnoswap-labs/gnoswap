package community_pool

import (
	"std"
)

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func assertUserCall() {
	if !isUserCall() {
		panic("must be called by user")
	}
}
