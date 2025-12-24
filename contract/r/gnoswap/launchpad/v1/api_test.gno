package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/onbloc/json"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/launchpad"
)

func TestApiGetDepositByDepositId_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetDepositByDepositId("nonexistent-deposit-id")

	if result != "" {
		t.Errorf("expected empty string for non-existent deposit, got %q", result)
	}
}

func TestApiGetDepositByDepositId_Found(t *testing.T) {
	resetTestStore()

	depositorAddr := testutils.TestAddress("depositor1")
	deposit := launchpad.NewDeposit(
		"deposit-1",
		"gno.land/r/test/token:100",
		30,
		depositorAddr,
		1000000,
		100,
		1700000000,
		1702592000,
	)

	deposits := testStore.GetDeposits()
	deposits.Set("deposit-1", deposit)
	testStore.SetDeposits(deposits)

	lp := getTestImplementation()
	result := lp.ApiGetDepositByDepositId("deposit-1")

	if result == "" {
		t.Fatal("expected non-empty result for existing deposit")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify JSON contains expected fields
	expectedFields := []string{
		"depositId",
		"projectId",
		"tier",
		"depositor",
		"amount",
		"depositHeight",
		"depositTime",
		"height",
		"now",
	}

	for _, field := range expectedFields {
		if !node.HasKey(field) {
			t.Errorf("result JSON missing expected field %q", field)
		}
	}

	// Verify specific values
	if node.MustKey("depositId").MustString() != "deposit-1" {
		t.Error("result should contain correct depositId")
	}
	if node.MustKey("tier").MustString() != "30" {
		t.Error("result should contain correct tier")
	}
	if node.MustKey("amount").MustString() != "1000000" {
		t.Error("result should contain correct amount")
	}
}

func TestApiGetProjectAndTierStatisticsByProjectId_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectAndTierStatisticsByProjectId("nonexistent-project-id")

	if result != "" {
		t.Errorf("expected empty string for non-existent project, got %q", result)
	}
}

func TestApiGetProjectAndTierStatisticsByProjectId_Found(t *testing.T) {
	resetTestStore()

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Test Project",
		"gno.land/r/test/token",
		10000000,
		recipientAddr,
		100,
		1700000000,
	)

	// Add tiers to project
	tier30 := launchpad.NewProjectTier(project.ID(), 30, 3000000, 1700003600, 1702595600)
	tier30.SetDistributeAmountPerSecondX128(u256.NewUint(1000))
	tier90 := launchpad.NewProjectTier(project.ID(), 90, 3000000, 1700003600, 1707779600)
	tier90.SetDistributeAmountPerSecondX128(u256.NewUint(500))
	tier180 := launchpad.NewProjectTier(project.ID(), 180, 4000000, 1700003600, 1715555600)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))

	tiers := map[int64]*launchpad.ProjectTier{
		30:  tier30,
		90:  tier90,
		180: tier180,
	}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	result := lp.ApiGetProjectAndTierStatisticsByProjectId(project.ID())

	if result == "" {
		t.Fatal("expected non-empty result for existing project")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify project fields
	projectFields := []string{
		"projectId",
		"name",
		"tokenPath",
		"depositAmount",
		"recipient",
	}

	for _, field := range projectFields {
		if !node.HasKey(field) {
			t.Errorf("result JSON missing expected project field %q", field)
		}
	}

	// Verify tier fields exist (for each tier duration)
	tierFields := []string{"tier30Id", "tier90Id", "tier180Id"}
	for _, field := range tierFields {
		if !node.HasKey(field) {
			t.Errorf("result JSON missing tier field %q", field)
		}
	}

	// Verify specific values
	if node.MustKey("name").MustString() != "Test Project" {
		t.Error("result should contain correct project name")
	}
}

func TestApiGetProjectStatisticsByProjectId_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectStatisticsByProjectId("nonexistent-project-id")

	if result != "" {
		t.Errorf("expected empty string for non-existent project, got %q", result)
	}
}

func TestApiGetProjectStatisticsByProjectId_Found(t *testing.T) {
	resetTestStore()

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Statistics Test",
		"gno.land/r/test/token",
		5000000,
		recipientAddr,
		200,
		1700000000,
	)

	// Add tier180 (required for getStandardTier)
	tier180 := launchpad.NewProjectTier(project.ID(), 180, 5000000, 1700003600, 1715555600)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))
	tiers := map[int64]*launchpad.ProjectTier{180: tier180}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	result := lp.ApiGetProjectStatisticsByProjectId(project.ID())

	if result == "" {
		t.Fatal("expected non-empty result for existing project")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify contains project info
	if node.MustKey("name").MustString() != "Statistics Test" {
		t.Error("result should contain project name")
	}
	if node.MustKey("depositAmount").MustString() != "5000000" {
		t.Error("result should contain deposit amount")
	}

	// Should contain refund info
	if !node.HasKey("refundedAmount") {
		t.Error("result should contain refundedAmount field")
	}
}

func TestApiGetTierStatisticsByProjectId_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetTierStatisticsByProjectId("nonexistent-project-id")

	if result != "" {
		t.Errorf("expected empty string for non-existent project, got %q", result)
	}
}

func TestApiGetTierStatisticsByProjectId_Found(t *testing.T) {
	resetTestStore()

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Tier Stats Test",
		"gno.land/r/test/token",
		9000000,
		recipientAddr,
		300,
		1700000000,
	)

	// Add all tiers
	tier30 := launchpad.NewProjectTier(project.ID(), 30, 2000000, 1700003600, 1702595600)
	tier30.SetDistributeAmountPerSecondX128(u256.NewUint(1000))
	tier30.SetTotalDepositAmount(500000)
	tier30.SetTotalDepositCount(5)

	tier90 := launchpad.NewProjectTier(project.ID(), 90, 3000000, 1700003600, 1707779600)
	tier90.SetDistributeAmountPerSecondX128(u256.NewUint(500))
	tier90.SetTotalDepositAmount(800000)
	tier90.SetTotalDepositCount(8)

	tier180 := launchpad.NewProjectTier(project.ID(), 180, 4000000, 1700003600, 1715555600)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))
	tier180.SetTotalDepositAmount(1200000)
	tier180.SetTotalDepositCount(12)

	tiers := map[int64]*launchpad.ProjectTier{
		30:  tier30,
		90:  tier90,
		180: tier180,
	}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	result := lp.ApiGetTierStatisticsByProjectId(project.ID())

	if result == "" {
		t.Fatal("expected non-empty result for existing project")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify tier fields exist
	tierFields := []string{
		"tier30TierAmount",
		"tier30TotalDepositAmount",
		"tier30TotalParticipant",
		"tier30Started",
		"tier30Ended",
	}

	for _, field := range tierFields {
		if !node.HasKey(field) {
			t.Errorf("result JSON missing expected tier field %q", field)
		}
	}

	// Verify specific tier values
	if node.MustKey("tier30TotalDepositAmount").MustString() != "500000" {
		t.Error("result should contain tier30 deposit amount")
	}
	if node.MustKey("tier90TotalDepositAmount").MustString() != "800000" {
		t.Error("result should contain tier90 deposit amount")
	}
	if node.MustKey("tier180TotalDepositAmount").MustString() != "1200000" {
		t.Error("result should contain tier180 deposit amount")
	}
}

func TestApiGetProjectStatisticsByProjectTierId_InvalidFormat(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()

	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic for invalid tier ID format")
		}
	}()

	// Invalid format: missing parts
	lp.ApiGetProjectStatisticsByProjectTierId("invalid-id")
}

func TestApiGetProjectStatisticsByProjectTierId_ProjectNotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectStatisticsByProjectTierId("gno.land/r/test/token:100:30")

	if result != "" {
		t.Errorf("expected empty string for non-existent project, got %q", result)
	}
}

func TestApiGetProjectStatisticsByProjectTierId_Found(t *testing.T) {
	resetTestStore()

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Tier ID Test",
		"gno.land/r/test/token",
		6000000,
		recipientAddr,
		100,
		1700000000,
	)

	tier30 := launchpad.NewProjectTier(project.ID(), 30, 2000000, 1700003600, 1702595600)
	tier30.SetDistributeAmountPerSecondX128(u256.NewUint(1000))
	tier30.SetTotalDepositAmount(750000)
	tier30.SetTotalDepositCount(7)

	tier180 := launchpad.NewProjectTier(project.ID(), 180, 4000000, 1700003600, 1715555600)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))

	tiers := map[int64]*launchpad.ProjectTier{
		30:  tier30,
		180: tier180,
	}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	tierId := project.ID() + ":30"
	result := lp.ApiGetProjectStatisticsByProjectTierId(tierId)

	if result == "" {
		t.Fatal("expected non-empty result for existing tier")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify tier-specific fields
	if !node.HasKey("tierId") {
		t.Error("result should contain tierId field")
	}
	if node.MustKey("tierTotalDepositAmount").MustString() != "750000" {
		t.Error("result should contain correct tier deposit amount")
	}
	if node.MustKey("tierTotalParticipant").MustString() != "7" {
		t.Error("result should contain correct tier participant count")
	}
}

func TestApiGetProjectActiveOf_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectActiveOf("nonexistent-project-id")

	if result != "" {
		t.Errorf("expected empty string for non-existent project, got %q", result)
	}
}

func TestApiGetProjectActiveOf_ActiveProject(t *testing.T) {
	resetTestStore()

	ctx := testing.GetContext()
	currentTime := time.Now().Unix()
	ctx.Time = time.Unix(currentTime, 0)
	testing.SetContext(ctx)

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Active Test",
		"gno.land/r/test/token",
		5000000,
		recipientAddr,
		100,
		currentTime-1000,
	)

	// Create tier that is currently active (startTime <= now < endTime)
	tier180 := launchpad.NewProjectTier(
		project.ID(),
		180,
		5000000,
		currentTime-500,    // started 500 seconds ago
		currentTime+100000, // ends in the future
	)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))

	tiers := map[int64]*launchpad.ProjectTier{180: tier180}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	result := lp.ApiGetProjectActiveOf(project.ID())

	if result == "" {
		t.Fatal("expected non-empty result for existing project")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify active status fields
	expectedFields := []string{
		"projectId",
		"isActive",
		"currentHeight",
		"startTime",
	}

	for _, field := range expectedFields {
		if !node.HasKey(field) {
			t.Errorf("result JSON missing expected field %q", field)
		}
	}

	// Should be active
	if node.MustKey("isActive").MustString() != "true" {
		t.Error("project should be active")
	}
}

func TestApiGetProjectActiveOf_InactiveProject(t *testing.T) {
	resetTestStore()

	ctx := testing.GetContext()
	currentTime := time.Now().Unix()
	ctx.Time = time.Unix(currentTime, 0)
	testing.SetContext(ctx)

	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Inactive Test",
		"gno.land/r/test/token",
		5000000,
		recipientAddr,
		100,
		currentTime-100000,
	)

	// Create tier that has ended (endTime < now)
	tier180 := launchpad.NewProjectTier(
		project.ID(),
		180,
		5000000,
		currentTime-100000, // started long ago
		currentTime-1000,   // ended 1000 seconds ago
	)
	tier180.SetDistributeAmountPerSecondX128(u256.NewUint(250))

	tiers := map[int64]*launchpad.ProjectTier{180: tier180}
	project.SetTiers(tiers)

	projects := testStore.GetProjects()
	projects.Set(project.ID(), project)
	testStore.SetProjects(projects)

	lp := getTestImplementation()
	result := lp.ApiGetProjectActiveOf(project.ID())

	if result == "" {
		t.Fatal("expected non-empty result for existing project")
	}

	node := json.Must(json.Unmarshal([]byte(result)))

	// Should be inactive
	if node.MustKey("isActive").MustString() != "false" {
		t.Error("project should be inactive")
	}
}

func TestApiGetProjectRecipientRewardByProjectId_NotFound(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectRecipientRewardByProjectId("nonexistent-project-id")

	// Returns "0" for non-existent projects
	if result != "0" {
		t.Errorf("expected '0' for non-existent project, got %q", result)
	}
}

func TestApiGetProjectRecipientRewardByAddress_InvalidAddress(t *testing.T) {
	resetTestStore()

	lp := getTestImplementation()
	result := lp.ApiGetProjectRecipientRewardByAddress("")

	if result != "0" {
		t.Errorf("expected '0' for invalid address, got %q", result)
	}
}

func TestDepositDataStructure(t *testing.T) {
	depositorAddr := testutils.TestAddress("depositor1")
	deposit := launchpad.NewDeposit(
		"test-deposit-1",
		"gno.land/r/test/token:100",
		90,
		depositorAddr,
		2000000,
		150,
		1700000000,
		1707776000,
	)

	// Verify all fields are accessible
	if deposit.ID() != "test-deposit-1" {
		t.Errorf("unexpected deposit ID: %s", deposit.ID())
	}
	if deposit.ProjectID() != "gno.land/r/test/token:100" {
		t.Errorf("unexpected project ID: %s", deposit.ProjectID())
	}
	if deposit.Tier() != 90 {
		t.Errorf("unexpected tier: %d", deposit.Tier())
	}
	if deposit.Depositor() != depositorAddr {
		t.Errorf("unexpected depositor: %s", deposit.Depositor())
	}
	if deposit.DepositAmount() != 2000000 {
		t.Errorf("unexpected deposit amount: %d", deposit.DepositAmount())
	}
	if deposit.CreatedHeight() != 150 {
		t.Errorf("unexpected created height: %d", deposit.CreatedHeight())
	}
	if deposit.CreatedAt() != 1700000000 {
		t.Errorf("unexpected created time: %d", deposit.CreatedAt())
	}
	if deposit.EndTime() != 1707776000 {
		t.Errorf("unexpected end time: %d", deposit.EndTime())
	}
}

func TestProjectDataStructure(t *testing.T) {
	recipientAddr := testutils.TestAddress("recipient1")
	project := launchpad.NewProject(
		"Structure Test",
		"gno.land/r/test/token",
		10000000,
		recipientAddr,
		200,
		1700000000,
	)

	// Verify all fields are accessible
	if project.Name() != "Structure Test" {
		t.Errorf("unexpected project name: %s", project.Name())
	}
	if project.TokenPath() != "gno.land/r/test/token" {
		t.Errorf("unexpected token path: %s", project.TokenPath())
	}
	if project.DepositAmount() != 10000000 {
		t.Errorf("unexpected deposit amount: %d", project.DepositAmount())
	}
	if project.Recipient() != recipientAddr {
		t.Errorf("unexpected recipient: %s", project.Recipient())
	}
	if project.CreatedHeight() != 200 {
		t.Errorf("unexpected created height: %d", project.CreatedHeight())
	}
	if project.CreatedAt() != 1700000000 {
		t.Errorf("unexpected created time: %d", project.CreatedAt())
	}

	// Verify ID format
	expectedID := "gno.land/r/test/token:200"
	if project.ID() != expectedID {
		t.Errorf("unexpected project ID format: got %s, want %s", project.ID(), expectedID)
	}
}

func TestProjectTierDataStructure(t *testing.T) {
	projectID := "gno.land/r/test/token:100"
	tier := launchpad.NewProjectTier(
		projectID,
		30,
		3000000,
		1700003600,
		1702595600,
	)

	// Verify all fields are accessible
	expectedTierID := "gno.land/r/test/token:100:30"
	if tier.ID() != expectedTierID {
		t.Errorf("unexpected tier ID format: got %s, want %s", tier.ID(), expectedTierID)
	}
	if tier.TotalDistributeAmount() != 3000000 {
		t.Errorf("unexpected distribute amount: %d", tier.TotalDistributeAmount())
	}
	if tier.StartTime() != 1700003600 {
		t.Errorf("unexpected start time: %d", tier.StartTime())
	}
	if tier.EndTime() != 1702595600 {
		t.Errorf("unexpected end time: %d", tier.EndTime())
	}

	// Verify initial counters are zero
	if tier.TotalDepositAmount() != 0 {
		t.Errorf("expected zero initial deposit amount, got %d", tier.TotalDepositAmount())
	}
	if tier.TotalDepositCount() != 0 {
		t.Errorf("expected zero initial deposit count, got %d", tier.TotalDepositCount())
	}
	if tier.TotalWithdrawAmount() != 0 {
		t.Errorf("expected zero initial withdraw amount, got %d", tier.TotalWithdrawAmount())
	}
	if tier.TotalWithdrawCount() != 0 {
		t.Errorf("expected zero initial withdraw count, got %d", tier.TotalWithdrawCount())
	}
	if tier.TotalCollectedAmount() != 0 {
		t.Errorf("expected zero initial collected amount, got %d", tier.TotalCollectedAmount())
	}
}

func TestProjectTierActivationStatus(t *testing.T) {
	projectID := "gno.land/r/test/token:100"
	startTime := int64(1700000000)
	endTime := int64(1702592000)

	tier := launchpad.NewProjectTier(projectID, 30, 3000000, startTime, endTime)

	testCases := []struct {
		name         string
		currentTime  int64
		expectActive bool
		expectEnded  bool
	}{
		{
			name:         "before start",
			currentTime:  startTime - 1000,
			expectActive: false,
			expectEnded:  false,
		},
		{
			name:         "at start time",
			currentTime:  startTime,
			expectActive: true,
			expectEnded:  false,
		},
		{
			name:         "during active period",
			currentTime:  (startTime + endTime) / 2,
			expectActive: true,
			expectEnded:  false,
		},
		{
			name:         "at end time",
			currentTime:  endTime,
			expectActive: false,
			expectEnded:  false,
		},
		{
			name:         "after end time",
			currentTime:  endTime + 1,
			expectActive: false,
			expectEnded:  true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			if tier.IsActivated(tc.currentTime) != tc.expectActive {
				t.Errorf("IsActivated(%d) = %v, want %v",
					tc.currentTime, tier.IsActivated(tc.currentTime), tc.expectActive)
			}
			if tier.IsEnded(tc.currentTime) != tc.expectEnded {
				t.Errorf("IsEnded(%d) = %v, want %v",
					tc.currentTime, tier.IsEnded(tc.currentTime), tc.expectEnded)
			}
		})
	}
}
