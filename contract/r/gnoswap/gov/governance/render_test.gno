package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRenderUnknownPath(cur realm, t *testing.T) {
	resetTestState(t)
	implementation = newMockGovernance("v1")

	uassert.Equal(t, "404\n", Render("proposals"))
}

func (m *MockGovernance) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ""
}
