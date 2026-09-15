package rbac

import (
	"strings"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prbac "gno.land/p/gnoswap/rbac/v1"
)

func TestRenderUnknownPath(cur realm, t *testing.T) {
	uassert.Equal(t, "404\n", Render("roles"))
}

func TestRenderReflectsOwnershipAndRoleUpdates(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac/v1"))
	originalManager := manager
	defer func() {
		manager = originalManager
	}()
	manager = prbac.NewRBACWithAddress(ADMIN)
	for role, addr := range _defaultRoleAddresses {
		if err := manager.RegisterRole(role.String(), addr); err != nil {
			t.Fatalf("failed to initialize role %s: %v", role.String(), err)
		}
	}

	originalRouter := _defaultRoleAddresses[prbac.ROLE_ROUTER]
	if !strings.Contains(Render(""), originalRouter.String()) {
		t.Fatal("initial router assignment is absent from rendered state")
	}

	pendingOwner := testutils.TestAddress("render-pending-owner")
	if err := manager.TransferOwnershipBy(pendingOwner, ADMIN); err != nil {
		t.Fatalf("failed to start ownership transfer: %v", err)
	}
	rendered := Render("")
	if !strings.Contains(rendered, pendingOwner.String()) {
		t.Errorf("Render() did not show pending owner %s:\n%s", pendingOwner, rendered)
	}

	if err := manager.AcceptOwnershipBy(pendingOwner); err != nil {
		t.Fatalf("failed to accept ownership: %v", err)
	}
	updatedRouter := testutils.TestAddress("render-router")
	if err := manager.UpdateRoleAddress(prbac.ROLE_ROUTER.String(), updatedRouter); err != nil {
		t.Fatalf("failed to update router role: %v", err)
	}

	rendered = Render("")
	for _, addr := range []address{pendingOwner, updatedRouter} {
		if !strings.Contains(rendered, addr.String()) {
			t.Errorf("updated address %s is absent from rendered state", addr)
		}
	}
	if strings.Contains(rendered, originalRouter.String()) {
		t.Error("rendered state still includes the replaced router address")
	}
}
