package launchpad

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRenderShowsStoredStateAndConfiguration(cur realm, t *testing.T) {
	setupTestEnvironment(cur, t, testEnvConfig{})
	instance := getTestImplementation()
	store := instance.store.(*testLaunchpadStore)

	store.projects.Set("project-1", true)
	store.projectRecipients.Set("recipient-1", true)
	store.projectTierRewardManagers.Set("project-1:30", true)
	store.deposits.Set("deposit-1", true)
	store.depositCounter.Next()
	store.totalGNSStakedAmount = 12_345_678

	rendered := instance.Render("")
	for _, want := range []string{
		"| Stored project records | 1 |",
		"| Stored unique project-recipient records | 1 |",
		"| Stored project-tier reward-manager records | 1 |",
		"| Stored deposit records (including withdrawn) | 1 |",
		"| Deposit ID counter (allocated IDs) | 1 |",
		"| Current GNS staked amount (base units; 6 decimals) | 12345678 |",
	} {
		uassert.True(t, strings.Contains(rendered, want))
	}

	store.projects.Set("project-2", true)
	rendered = instance.Render("")
	uassert.True(t, strings.Contains(rendered, "| Stored project records | 2 |"))
}

func TestRenderUnknownPathReturns404BeforeStateAccess(cur realm, t *testing.T) {
	setupTestEnvironment(cur, t, testEnvConfig{})
	instance := getTestImplementation()
	store := instance.store
	instance.store = nil
	defer func() { instance.store = store }()

	uassert.Equal(t, "404\n", instance.Render("unsupported"))
}
