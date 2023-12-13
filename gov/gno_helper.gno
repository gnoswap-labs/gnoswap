package gov

import (
	"std"
)

func GetOrigPkgAddr() std.Address {
	return std.DerivePkgAddr("gno.land/r/demo/gov")
}
