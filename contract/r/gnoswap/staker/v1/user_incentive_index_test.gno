package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestUserIncentiveIndex_AddReference(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")
	incentiveId1 := "incentive-1"
	poolPath1 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	// Add first reference
	instance.addUserIncentiveReference(user1, incentiveId1, poolPath1)

	// Verify reference was added
	refs := instance.getUserIncentiveReferences(user1)
	uassert.Equal(t, 1, len(refs), "should have 1 reference")
	uassert.Equal(t, incentiveId1, refs[0].IncentiveId(), "incentive ID should match")
	uassert.Equal(t, poolPath1, refs[0].PoolPath(), "pool path should match")
	uassert.False(t, refs[0].IsArchived(), "should not be archived initially")
}

func TestUserIncentiveIndex_MultipleReferences(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")
	incentiveId1 := "incentive-1"
	incentiveId2 := "incentive-2"
	poolPath1 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	poolPath2 := "gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500"

	// Add multiple references
	instance.addUserIncentiveReference(user1, incentiveId1, poolPath1)
	instance.addUserIncentiveReference(user1, incentiveId2, poolPath2)

	// Verify both references exist
	refs := instance.getUserIncentiveReferences(user1)
	uassert.Equal(t, 2, len(refs), "should have 2 references")
}

func TestUserIncentiveIndex_UpdateArchiveStatus(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")
	incentiveId1 := "incentive-1"
	poolPath1 := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	// Add reference
	instance.addUserIncentiveReference(user1, incentiveId1, poolPath1)

	// Verify initially not archived
	refs := instance.getUserIncentiveReferences(user1)
	uassert.False(t, refs[0].IsArchived(), "should not be archived initially")

	// Update to archived
	instance.updateUserIncentiveArchiveStatus(user1, incentiveId1, true)

	// Verify archived status updated
	refs = instance.getUserIncentiveReferences(user1)
	uassert.True(t, refs[0].IsArchived(), "should be archived after update")

	// Update back to active
	instance.updateUserIncentiveArchiveStatus(user1, incentiveId1, false)

	// Verify archived status updated again
	refs = instance.getUserIncentiveReferences(user1)
	uassert.False(t, refs[0].IsArchived(), "should not be archived after second update")
}

func TestUserIncentiveIndex_FilterActiveAndArchived(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")
	incentiveId1 := "incentive-1"
	incentiveId2 := "incentive-2"
	incentiveId3 := "incentive-3"
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	// Add 3 references
	instance.addUserIncentiveReference(user1, incentiveId1, poolPath)
	instance.addUserIncentiveReference(user1, incentiveId2, poolPath)
	instance.addUserIncentiveReference(user1, incentiveId3, poolPath)

	// Archive 2 of them
	instance.updateUserIncentiveArchiveStatus(user1, incentiveId1, true)
	instance.updateUserIncentiveArchiveStatus(user1, incentiveId2, true)

	// Get all references
	allRefs := instance.getUserIncentiveReferences(user1)
	uassert.Equal(t, 3, len(allRefs), "should have 3 total references")

	// Get active references
	activeRefs := instance.getUserActiveIncentiveReferences(user1)
	uassert.Equal(t, 1, len(activeRefs), "should have 1 active reference")
	uassert.Equal(t, incentiveId3, activeRefs[0].IncentiveId(), "active reference should be incentive-3")

	// Get archived references
	archivedRefs := instance.getUserArchivedIncentiveReferences(user1)
	uassert.Equal(t, 2, len(archivedRefs), "should have 2 archived references")
}

func TestUserIncentiveIndex_MultipleUsers(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")
	user2 := testutils.TestAddress("user2")
	incentiveId1 := "incentive-1"
	incentiveId2 := "incentive-2"
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	// Add references for different users
	instance.addUserIncentiveReference(user1, incentiveId1, poolPath)
	instance.addUserIncentiveReference(user2, incentiveId2, poolPath)

	// Verify user1's references
	user1Refs := instance.getUserIncentiveReferences(user1)
	uassert.Equal(t, 1, len(user1Refs), "user1 should have 1 reference")
	uassert.Equal(t, incentiveId1, user1Refs[0].IncentiveId(), "user1's reference should be incentive-1")

	// Verify user2's references
	user2Refs := instance.getUserIncentiveReferences(user2)
	uassert.Equal(t, 1, len(user2Refs), "user2 should have 1 reference")
	uassert.Equal(t, incentiveId2, user2Refs[0].IncentiveId(), "user2's reference should be incentive-2")
}

func TestUserIncentiveIndex_EmptyUser(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	user1 := testutils.TestAddress("user1")

	// Get references for user with no incentives
	refs := instance.getUserIncentiveReferences(user1)
	uassert.Equal(t, 0, len(refs), "should have no references")

	activeRefs := instance.getUserActiveIncentiveReferences(user1)
	uassert.Equal(t, 0, len(activeRefs), "should have no active references")

	archivedRefs := instance.getUserArchivedIncentiveReferences(user1)
	uassert.Equal(t, 0, len(archivedRefs), "should have no archived references")
}
