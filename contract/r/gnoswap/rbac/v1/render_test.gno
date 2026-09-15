package rbac

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	prbac "gno.land/p/gnoswap/rbac/v1"
)

func TestRenderUnknownPath(cur realm, t *testing.T) {
	uassert.Equal(t, "404\n", Render("roles"))
}

func TestRenderShowsOwnerAndUnassignedRoles(cur realm, t *testing.T) {
	originalManager := manager
	defer func() {
		manager = originalManager
	}()
	manager = prbac.NewRBACWithAddress(ADMIN)
	if err := manager.RegisterRole(prbac.ROLE_ADMIN.String(), ADMIN); err != nil {
		t.Fatalf("failed to initialize admin role: %v", err)
	}

	rendered := Render("")
	for _, want := range []string{
		"| Owner | " + ADMIN.String() + " |",
		"| Pending owner | None |",
		"| admin | " + ADMIN.String() + " |",
		"| router | Unassigned |",
		"| protocol_fee | Unassigned |",
	} {
		if !strings.Contains(rendered, want) {
			t.Errorf("Render() missing %q in:\n%s", want, rendered)
		}
	}
}

func TestRenderReflectsOwnershipAndRoleUpdates(cur realm, t *testing.T) {
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

	pendingOwner := DEV_OPS
	if err := manager.TransferOwnershipBy(pendingOwner, ADMIN); err != nil {
		t.Fatalf("failed to start ownership transfer: %v", err)
	}
	rendered := Render("")
	if !strings.Contains(rendered, "| Pending owner | "+pendingOwner.String()+" |") {
		t.Errorf("Render() did not show pending owner %s:\n%s", pendingOwner, rendered)
	}

	if err := manager.AcceptOwnershipBy(pendingOwner); err != nil {
		t.Fatalf("failed to accept ownership: %v", err)
	}
	if err := manager.UpdateRoleAddress(prbac.ROLE_ROUTER.String(), pendingOwner); err != nil {
		t.Fatalf("failed to update router role: %v", err)
	}

	rendered = Render("")
	for _, want := range []string{
		"| Owner | " + pendingOwner.String() + " |",
		"| Pending owner | None |",
		"| router | " + pendingOwner.String() + " |",
	} {
		if !strings.Contains(rendered, want) {
			t.Errorf("Render() missing updated state %q in:\n%s", want, rendered)
		}
	}
}
