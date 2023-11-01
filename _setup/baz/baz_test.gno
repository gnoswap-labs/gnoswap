package foo

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/demo/users"
)

var (
	a1 = testutils.TestAddress("a1")
	a2 = testutils.TestAddress("a2")
	a3 = testutils.TestAddress("a3")
	a4 = testutils.TestAddress("a4")
)

func init() {
	std.TestSetOrigCaller(a1)
	Faucet()
}

func TestTransfer(t *testing.T) {
	std.TestSetOrigCaller(a1)
	Transfer(a2u(a2), 100)

	std.TestSetOrigCaller(a2)
	Transfer(a2u(a3), 95)

	shouldPanicWithMsg(t, func() { Transfer(a2u(a3), 10) }, "insufficient balance")
}

func TestApprove(t *testing.T) {
	std.TestSetOrigCaller(std.Address(""))
	shouldPanicWithMsg(t, func() { Approve(a2u(a2), 1000) }, "invalid address")

	std.TestSetOrigCaller(a1)
	shouldPanicWithMsg(t, func() { Approve(a2u(std.Address("")), 1000) }, "invalid address")
}

func TestTransferFrom(t *testing.T) {
	std.TestSetOrigCaller(a1)
	Approve(a2u(a2), 1000)

	std.TestSetOrigCaller(a2)
	TransferFrom(a2u(a1), a2u(a3), 100)

	// not enough allowance
	shouldPanicWithMsg(t, func() { TransferFrom(a2u(a1), a2u(a3), 901) }, "insufficient allowance")

	// didn't approve
	std.TestSetOrigCaller(a3)
	shouldPanicWithMsg(t, func() { TransferFrom(a2u(a1), a2u(a4), 100) }, "insufficient allowance")

}

func a2u(addr std.Address) users.AddressOrName {
	return users.AddressOrName(addr)
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
