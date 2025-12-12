package v1

import (
	"gno.land/p/nt/avl"
	sr "gno.land/r/gnoswap/staker"
)

// addUserIncentiveReference adds an incentive reference to a user's incentive index
// This enables O(log n) lookup of user's incentives instead of O(all_incentives) iteration
func (s *stakerV1) addUserIncentiveReference(user address, incentiveId, poolPath string) {
	userIncentives := s.store.GetUserIncentives()

	// Get or create user's incentive tree
	userTreeI, exists := userIncentives.Get(user.String())
	var userTree *avl.Tree
	if !exists {
		userTree = avl.NewTree()
	} else {
		var ok bool
		userTree, ok = userTreeI.(*avl.Tree)
		if !ok {
			panic("failed to cast user incentive tree")
		}
	}

	// Add incentive reference
	ref := sr.NewIncentiveReference(incentiveId, poolPath, false)
	userTree.Set(incentiveId, ref)

	// Update user's tree in global index
	userIncentives.Set(user.String(), userTree)
}

// updateUserIncentiveArchiveStatus updates the archive status of a user's incentive reference
func (s *stakerV1) updateUserIncentiveArchiveStatus(user address, incentiveId string, isArchived bool) {
	userIncentives := s.store.GetUserIncentives()

	userTreeI, exists := userIncentives.Get(user.String())
	if !exists {
		return
	}

	userTree, ok := userTreeI.(*avl.Tree)
	if !ok {
		panic("failed to cast user incentive tree")
	}

	refI, exists := userTree.Get(incentiveId)
	if !exists {
		return
	}

	ref, ok := refI.(*sr.IncentiveReference)
	if !ok {
		panic("failed to cast incentive reference")
	}

	ref.SetIsArchived(isArchived)
	userTree.Set(incentiveId, ref)
	userIncentives.Set(user.String(), userTree)
}

// getUserIncentiveReferences returns all incentive references for a user
func (s *stakerV1) getUserIncentiveReferences(user address) []*sr.IncentiveReference {
	userIncentives := s.store.GetUserIncentives()

	userTreeI, exists := userIncentives.Get(user.String())
	if !exists {
		return []*sr.IncentiveReference{}
	}

	userTree, ok := userTreeI.(*avl.Tree)
	if !ok {
		panic("failed to cast user incentive tree")
	}

	refs := []*sr.IncentiveReference{}
	userTree.Iterate("", "", func(_ string, value any) bool {
		ref, ok := value.(*sr.IncentiveReference)
		if !ok {
			panic("failed to cast incentive reference")
		}
		refs = append(refs, ref)
		return false
	})

	return refs
}

// getUserActiveIncentiveReferences returns only active (non-archived) incentive references for a user
func (s *stakerV1) getUserActiveIncentiveReferences(user address) []*sr.IncentiveReference {
	allRefs := s.getUserIncentiveReferences(user)
	activeRefs := []*sr.IncentiveReference{}

	for _, ref := range allRefs {
		if !ref.IsArchived() {
			activeRefs = append(activeRefs, ref)
		}
	}

	return activeRefs
}

// getUserArchivedIncentiveReferences returns only archived incentive references for a user
func (s *stakerV1) getUserArchivedIncentiveReferences(user address) []*sr.IncentiveReference {
	allRefs := s.getUserIncentiveReferences(user)
	archivedRefs := []*sr.IncentiveReference{}

	for _, ref := range allRefs {
		if ref.IsArchived() {
			archivedRefs = append(archivedRefs, ref)
		}
	}

	return archivedRefs
}
