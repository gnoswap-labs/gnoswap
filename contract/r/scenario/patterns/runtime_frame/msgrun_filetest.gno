// PKGPATH: gno.land/e/g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5/run
package run

import "chain/runtime"

func main() {
	current := runtime.CurrentRealm()

	assertString("MsgRun Address()", current.Address().String(), "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")
	assertString("MsgRun PkgPath()", current.PkgPath(), "gno.land/e/g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5/run")
	assertBool("MsgRun IsUser()", current.IsUser(), true)
	assertBool("MsgRun IsCode()", current.IsCode(), true)

	println("MsgRun frame verified")
}

func assertString(name string, got string, want string) {
	if got != want {
		panic(name + " = " + got + ", want " + want)
	}
}

func assertBool(name string, got bool, want bool) {
	if got != want {
		panic(name + " = " + boolString(got) + ", want " + boolString(want))
	}
}

func boolString(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

// Output:
// MsgRun frame verified
