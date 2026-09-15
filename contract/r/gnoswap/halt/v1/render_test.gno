package halt

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRender(cur realm, t *testing.T) {
	originalStates := haltStates.ToConfig()
	defer func() {
		haltStates = newHaltStateManagerByConfig(originalStates)
	}()
	uassert.Equal(t, "404\n", Render("status"))

	err := setHaltLevel(HaltLevelSafeMode)
	uassert.NoError(t, err)

	rendered := Render("")
	for _, want := range []string{
		"| Pool | false |",
		"| Position | false |",
		"| Protocol fee | false |",
		"| Router | false |",
		"| Staker | false |",
		"| Launchpad | false |",
		"| Governance | false |",
		"| Governance staker | false |",
		"| xGNS | false |",
		"| Community pool | false |",
		"| Emission | false |",
		"| Withdraw | true |",
	} {
		if !strings.Contains(rendered, want) {
			t.Errorf("Render() missing %q in:\n%s", want, rendered)
		}
	}

	err = setHaltLevel(HaltLevelComplete)
	uassert.NoError(t, err)
	rendered = Render("")
	for _, operation := range []string{
		"Pool", "Position", "Protocol fee", "Router", "Staker",
		"Launchpad", "Governance", "Governance staker", "xGNS",
		"Community pool", "Emission", "Withdraw",
	} {
		want := "| " + operation + " | true |"
		if !strings.Contains(rendered, want) {
			t.Errorf("Render() missing halted operation %q in:\n%s", operation, rendered)
		}
	}
}
