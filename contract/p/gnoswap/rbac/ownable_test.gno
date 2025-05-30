package rbac

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/urequire"
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")
)

func TestNewOwnable2Step(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()
	got := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, got, alice)
	uassert.Equal(t, pendingOwner.String(), "")
}

func TestInitiateTransferOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.TransferOwnership(bob)
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, owner, alice)
	uassert.Equal(t, pendingOwner, bob)
}

func TestTransferOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.TransferOwnership(bob)
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, owner, alice)
	uassert.Equal(t, pendingOwner, bob)

	testing.SetOriginCaller(bob)

	err = o.AcceptOwnership()
	urequire.NoError(t, err)

	owner = o.Owner()
	pendingOwner = o.PendingOwner()

	uassert.Equal(t, owner, bob)
	uassert.Equal(t, pendingOwner.String(), "")
}

func TestDropOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.DropOwnership()
	urequire.NoError(t, err, "DropOwnership failed")

	owner := o.Owner()
	uassert.Empty(t, owner, "owner should be empty")
}

func TestDropOwnershipVulnerability(t *testing.T) {
	testing.SetOriginCaller(alice)
	o := NewOwnable2Step()

	// alice initiates ownership transfer to bob
	err := o.TransferOwnership(bob)
	urequire.NoError(t, err)

	// alice drops ownership while ownership transfer is pending
	err = o.DropOwnership()
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()
	uassert.Empty(t, owner, "owner should be empty")
	uassert.Empty(t, pendingOwner.String(), "pending owner should be empty")

	// verify bob can no longer claim ownership
	testing.SetOriginCaller(bob)
	err = o.AcceptOwnership()
	uassert.ErrorContains(t, err, ErrNoPendingOwner.Error())
}

// Errors

func TestErrUnauthorized(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	testing.SetOriginCaller(bob)

	uassert.ErrorContains(t, o.TransferOwnership(alice), ErrUnauthorized.Error())
	uassert.ErrorContains(t, o.DropOwnership(), ErrUnauthorized.Error())
}

func TestErrInvalidAddress(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.TransferOwnership("")
	uassert.ErrorContains(t, err, ErrInvalidAddress.Error())

	err = o.TransferOwnership("10000000001000000000100000000010000000001000000000")
	uassert.ErrorContains(t, err, ErrInvalidAddress.Error())
}

func TestErrNoPendingOwner(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.AcceptOwnership()
	uassert.ErrorContains(t, err, ErrNoPendingOwner.Error())
}

func TestErrPendingUnauthorized(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := NewOwnable2Step()

	err := o.TransferOwnership(bob)
	urequire.NoError(t, err)

	testing.SetOriginCaller(alice)

	err = o.AcceptOwnership()
	uassert.ErrorContains(t, err, ErrPendingUnauthorized.Error())
}
