package v1

import (
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/gov/governance"
)


// GetLatestConfigVersion returns the current config version.
func (gv *governanceV1) GetLatestConfigVersion() int64 {
	return gv.getCurrentConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
func (gv *governanceV1) GetCurrentProposalID() int64 {
	return gv.getCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
func (gv *governanceV1) GetMaxSmoothingPeriod() int64 {
	return maxSmoothingPeriod
}


// GetLatestConfig returns the latest governance configuration.
func (gv *governanceV1) GetLatestConfig() governance.Config {
	currentVersion := gv.getCurrentConfigVersion()
	config, ok := gv.getConfig(currentVersion)
	if !ok {
		panic(errDataNotFound)
	}

	return config
}

// GetConfig returns a specific governance configuration by version.
func (gv *governanceV1) GetConfig(configVersion int64) (governance.Config, error) {
	config, ok := gv.getConfig(configVersion)
	if !ok {
		return governance.Config{}, ufmt.Errorf("config version %d not found", configVersion)
	}

	return config, nil
}


// GetProposalCount returns the total number of proposals.
func (gv *governanceV1) GetProposalCount() int {
	return gv.store.GetProposals().Size()
}

// GetProposalIDs returns a paginated list of proposal IDs.
func (gv *governanceV1) GetProposalIDs(offset, count int) []int64 {
	proposals := gv.store.GetProposals()
	size := proposals.Size()

	if offset >= size {
		return []int64{}
	}

	end := offset + count
	if end > size {
		end = size
	}

	ids := make([]int64, 0, end-offset)
	proposals.IterateByOffset(offset, end-offset, func(key string, value any) bool {
		proposal := value.(*governance.Proposal)
		ids = append(ids, proposal.ID())
		return false
	})

	return ids
}

// ExistsProposal checks if a proposal exists.
func (gv *governanceV1) ExistsProposal(proposalID int64) bool {
	_, exists := gv.store.GetProposal(proposalID)
	return exists
}

// GetProposal returns a proposal by ID.
func (gv *governanceV1) GetProposal(proposalID int64) (*governance.Proposal, error) {
	proposal, exists := gv.store.GetProposal(proposalID)
	if !exists {
		return nil, ufmt.Errorf("proposal %d not found", proposalID)
	}
	return proposal, nil
}

// GetProposerByProposalId returns the proposer address of a proposal.
func (gv *governanceV1) GetProposerByProposalId(proposalId int64) (address, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Proposer(), nil
}

// GetProposalTypeByProposalId returns the type of a proposal.
func (gv *governanceV1) GetProposalTypeByProposalId(proposalId int64) (governance.ProposalType, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return governance.ProposalType(0), ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Type(), nil
}

// GetYeaByProposalId returns the yes vote weight of a proposal.
func (gv *governanceV1) GetYeaByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().YesWeight(), nil
}

// GetNayByProposalId returns the no vote weight of a proposal.
func (gv *governanceV1) GetNayByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().NoWeight(), nil
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
func (gv *governanceV1) GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.ConfigVersion(), nil
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
func (gv *governanceV1) GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().VoteStatus().QuorumAmount(), nil
}

// GetTitleByProposalId returns the title of a proposal.
func (gv *governanceV1) GetTitleByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Title(), nil
}

// GetDescriptionByProposalId returns the description of a proposal.
func (gv *governanceV1) GetDescriptionByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Description(), nil
}

// GetProposalStatusByProposalId returns the current status of a proposal.
func (gv *governanceV1) GetProposalStatusByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	proposalResolver := NewProposalResolver(proposal)
	return proposalResolver.Status(time.Now().Unix()), nil
}


// GetVoteStatus returns the vote status of a proposal.
//
// Returns:
//   - quorum: minimum vote weight required for proposal to pass
//   - maxVotingWeight: maximum possible voting weight
//   - yesWeight: total weight of "yes" votes
//   - noWeight: total weight of "no" votes
func (gv *governanceV1) GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, 0, 0, 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	voting := proposal.Status().VoteStatus()
	return voting.QuorumAmount(), voting.MaxVotingWeight(), voting.YesWeight(), voting.NoWeight(), nil
}

// GetVotingInfoCount returns the number of voters for a proposal.
func (gv *governanceV1) GetVotingInfoCount(proposalID int64) int {
	votingInfos, exists := gv.getProposalUserVotingInfos(proposalID)
	if !exists {
		return 0
	}
	return votingInfos.Size()
}

// GetVotingInfoAddresses returns a paginated list of voter addresses for a proposal.
func (gv *governanceV1) GetVotingInfoAddresses(proposalID int64, offset, count int) []address {
	votingInfos, exists := gv.getProposalUserVotingInfos(proposalID)
	if !exists {
		return []address{}
	}

	size := votingInfos.Size()
	if offset >= size {
		return []address{}
	}

	end := offset + count
	if end > size {
		end = size
	}

	addrs := make([]address, 0, end-offset)
	votingInfos.IterateByOffset(offset, end-offset, func(key string, value any) bool {
		addrs = append(addrs, address(key))
		return false
	})

	return addrs
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
func (gv *governanceV1) ExistsVotingInfo(proposalID int64, addr address) bool {
	_, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	return exists
}

// GetVotingInfo returns the voting info for a user on a proposal.
func (gv *governanceV1) GetVotingInfo(proposalID int64, addr address) (*governance.VotingInfo, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return nil, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo, nil
}

// GetVoteWeight returns the voting weight of an address for a proposal.
func (gv *governanceV1) GetVoteWeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedWeight(), nil
}

// GetVotedHeight returns the block height when an address voted on a proposal.
func (gv *governanceV1) GetVotedHeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedHeight(), nil
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
func (gv *governanceV1) GetVotedAt(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedAt(), nil
}


// GetUserProposalCount returns the number of proposals created by a user.
func (gv *governanceV1) GetUserProposalCount(user address) int {
	proposalIDs, exists := gv.store.GetUserProposalIDs(user.String())
	if !exists {
		return 0
	}
	return len(proposalIDs)
}

// GetUserProposalIDs returns a paginated list of proposal IDs created by a user.
func (gv *governanceV1) GetUserProposalIDs(user address, offset, count int) []int64 {
	proposalIDs, exists := gv.store.GetUserProposalIDs(user.String())
	if !exists {
		return []int64{}
	}

	size := len(proposalIDs)
	if offset >= size {
		return []int64{}
	}

	end := offset + count
	if end > size {
		end = size
	}

	return proposalIDs[offset:end]
}


// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
// This is used by gov/staker to prevent cleanup of delegation history that is still needed
// by active proposals for voting weight calculation.
func (gv *governanceV1) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	currentTime := time.Now().Unix()
	currentProposalID := gv.getCurrentProposalID()

	var (
		oldestSnapshotTime int64
		hasActiveProposal  bool
	)

	for id := int64(1); id <= currentProposalID; id++ {
		proposal, exists := gv.getProposal(id)
		if !exists {
			continue
		}

		proposalResolver := NewProposalResolver(proposal)

		if proposalResolver.IsActive(currentTime) {
			snapshotTime := proposal.SnapshotTime()
			if !hasActiveProposal || snapshotTime < oldestSnapshotTime {
				oldestSnapshotTime = snapshotTime
				hasActiveProposal = true
			}
		}
	}

	return oldestSnapshotTime, hasActiveProposal
}


// GetCurrentVotingWeightSnapshot returns the current voting weight snapshot.
func (gv *governanceV1) GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	current := time.Now().Unix()
	config, ok := gv.getCurrentConfig()
	if !ok {
		return 0, 0, ufmt.Errorf("current config not found")
	}

	return gv.getVotingWeightSnapshot(current, config.VotingWeightSmoothingDuration)
}
