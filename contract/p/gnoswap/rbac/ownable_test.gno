package rbac

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/urequire"
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")
)

func TestNewWithAddress(t *testing.T) {
	o := newOwnable2StepWithAddress(alice)

	got := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, got, alice)
	uassert.Equal(t, pendingOwner.String(), "")
}

func TestInitiateTransferOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, owner, alice)
	uassert.Equal(t, pendingOwner, bob)
}

func TestTransferOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()

	uassert.Equal(t, owner, alice)
	uassert.Equal(t, pendingOwner, bob)

	testing.SetOriginCaller(bob)

	err = o.AcceptOwnershipBy(bob)
	urequire.NoError(t, err)

	owner = o.Owner()
	pendingOwner = o.PendingOwner()

	uassert.Equal(t, owner, bob)
	uassert.Equal(t, pendingOwner.String(), "")
}

func TestOwnedByOriginCaller(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)
	unauthorizedCaller := bob
	testing.SetOriginCaller(unauthorizedCaller)
	uassert.False(t, o.IsOwner(unauthorizedCaller))
}

func TestOwnedByOriginCallerUnauthorized(t *testing.T) {
	testing.SetOriginCaller(alice)
	testing.SetRealm(testing.NewUserRealm(alice))

	var o *Ownable2Step
	func() {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/test/test"))
		o = newOwnable2StepWithAddress(alice)
	}()

	uassert.True(t, o.IsOwner(alice))

	unauthorizedCaller := bob
	testing.SetRealm(testing.NewUserRealm(unauthorizedCaller))
	uassert.False(t, o.IsOwner(unauthorizedCaller))
}

func TestDropOwnership(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := New()

	err := o.DropOwnershipBy(alice)
	urequire.NoError(t, err, "DropOwnership failed")

	owner := o.Owner()
	uassert.Empty(t, owner, "owner should be empty")
}

func TestDropOwnershipVulnerability(t *testing.T) {
	testing.SetOriginCaller(alice)
	o := New()

	// alice initiates ownership transfer to bob
	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	// alice drops ownership while ownership transfer is pending
	err = o.DropOwnershipBy(alice)
	urequire.NoError(t, err)

	owner := o.Owner()
	pendingOwner := o.PendingOwner()
	uassert.Empty(t, owner, "owner should be empty")
	uassert.Empty(t, pendingOwner.String(), "pending owner should be empty")

	// verify bob can no longer claim ownership
	testing.SetOriginCaller(bob)
	err = o.AcceptOwnershipBy(bob)
	uassert.ErrorContains(t, err, ErrNoPendingOwner.Error())
}

// Errors

func TestErrUnauthorized(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := New()

	testing.SetOriginCaller(bob)

	uassert.ErrorContains(t, o.TransferOwnershipBy(alice, bob), ErrUnauthorized.Error())
	uassert.ErrorContains(t, o.DropOwnershipBy(bob), ErrUnauthorized.Error())
}

func TestErrInvalidAddress(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := New()

	err := o.TransferOwnershipBy("", alice)
	uassert.ErrorContains(t, err, ErrInvalidAddress.Error())

	err = o.TransferOwnershipBy("10000000001000000000100000000010000000001000000000", alice)
	uassert.ErrorContains(t, err, ErrInvalidAddress.Error())
}

func TestErrNoPendingOwner(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := New()

	err := o.AcceptOwnershipBy(alice)
	uassert.ErrorContains(t, err, ErrNoPendingOwner.Error())
}

func TestErrPendingUnauthorized(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := New()

	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	testing.SetOriginCaller(alice)

	err = o.AcceptOwnershipBy(alice)
	uassert.ErrorContains(t, err, ErrPendingUnauthorized.Error())
}

// Edge Cases

func TestOwnable_IsPendingOwnerScenarios(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	// Before transfer: no one is pending owner
	uassert.False(t, o.IsPendingOwner(alice))
	uassert.False(t, o.IsPendingOwner(bob))

	// Initiate transfer to bob
	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	// After transfer: bob is pending owner, alice is not
	uassert.False(t, o.IsPendingOwner(alice))
	uassert.True(t, o.IsPendingOwner(bob))

	// Accept ownership
	testing.SetOriginCaller(bob)
	err = o.AcceptOwnershipBy(bob)
	urequire.NoError(t, err)

	// After accept: no one is pending owner
	uassert.False(t, o.IsPendingOwner(alice))
	uassert.False(t, o.IsPendingOwner(bob))
}

func TestOwnable_MultipleTransferAttempts(t *testing.T) {
	charlie := testutils.TestAddress("charlie")

	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	// First transfer to bob
	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	pendingOwner := o.PendingOwner()
	uassert.Equal(t, pendingOwner, bob)

	// Second transfer to charlie (should update pending owner)
	err = o.TransferOwnershipBy(charlie, alice)
	urequire.NoError(t, err)

	pendingOwner = o.PendingOwner()
	uassert.Equal(t, pendingOwner, charlie)

	// Bob should not be able to accept (no longer pending owner)
	testing.SetOriginCaller(bob)
	err = o.AcceptOwnershipBy(bob)
	uassert.ErrorContains(t, err, ErrPendingUnauthorized.Error())

	// Only charlie can accept
	testing.SetOriginCaller(charlie)
	err = o.AcceptOwnershipBy(charlie)
	urequire.NoError(t, err)

	owner := o.Owner()
	uassert.Equal(t, owner, charlie)
}

func TestOwnable_TransferToSelf(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	// Transfer ownership to self
	err := o.TransferOwnershipBy(alice, alice)
	urequire.NoError(t, err)

	// Alice should be pending owner
	pendingOwner := o.PendingOwner()
	uassert.Equal(t, pendingOwner, alice)

	// Alice can accept (completes transfer to self)
	err = o.AcceptOwnershipBy(alice)
	urequire.NoError(t, err)

	// Alice remains owner
	owner := o.Owner()
	uassert.Equal(t, owner, alice)

	// No pending owner after accept
	pendingOwner = o.PendingOwner()
	uassert.Equal(t, pendingOwner.String(), "")
}

func TestOwnable_AcceptAfterAccepted(t *testing.T) {
	testing.SetOriginCaller(alice)

	o := newOwnable2StepWithAddress(alice)

	// Transfer to bob
	err := o.TransferOwnershipBy(bob, alice)
	urequire.NoError(t, err)

	// Bob accepts
	testing.SetOriginCaller(bob)
	err = o.AcceptOwnershipBy(bob)
	urequire.NoError(t, err)

	owner := o.Owner()
	uassert.Equal(t, owner, bob)

	// Bob tries to accept again (should fail - no pending owner)
	err = o.AcceptOwnershipBy(bob)
	uassert.ErrorContains(t, err, ErrNoPendingOwner.Error())
}
