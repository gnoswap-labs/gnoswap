package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRenderUnknownPath(cur realm, t *testing.T) {
	resetTestState(t)
	implementation = newMockGovStaker("v1")

	uassert.Equal(t, "404\n", Render("delegations"))
}

func (m *MockGovStaker) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ""
}
