package staker2

import (
	"std"

	"gno.land/p/demo/avl"
)

// StakerManager manages all staker states and ensures atomic operations
type StakerManager struct {
	stakers       *avl.Tree           // address -> *StakerState
	totalStaked   uint64              // Total staked across all stakers
	epochManager  *EpochManager       // Reference to epoch manager
	votingManager *VotingPowerManager // Reference to voting power manager
	rewardManager *RewardManager      // Reference to reward manager
}

// NewStakerManager creates a new staker manager
func NewStakerManager(em *EpochManager, vpm *VotingPowerManager, rm *RewardManager) *StakerManager {
	return &StakerManager{
		stakers:       avl.NewTree(),
		totalStaked:   0,
		epochManager:  em,
		votingManager: vpm,
		rewardManager: rm,
	}
}

// GetOrCreateStaker retrieves or creates a staker state
func (sm *StakerManager) GetOrCreateStaker(address std.Address) *StakerState {
	addrStr := address.String()
	if value, exists := sm.stakers.Get(addrStr); exists {
		return value.(*StakerState)
	}

	// Create new staker
	staker := NewStakerState(address)
	sm.stakers.Set(addrStr, staker)
	return staker
}

// GetStaker retrieves a staker state (returns nil if not found)
func (sm *StakerManager) GetStaker(address std.Address) *StakerState {
	addrStr := address.String()
	if value, exists := sm.stakers.Get(addrStr); exists {
		return value.(*StakerState)
	}
	return nil
}

// UpdateStakerDelegation updates a staker's delegation atomically
func (sm *StakerManager) UpdateStakerDelegation(
	staker std.Address,
	delegatee std.Address,
	amount uint64,
	isIncrease bool,
) error {
	// Get current epoch
	currentEpoch := sm.epochManager.GetCurrentEpoch()

	// Get or create staker state
	stakerState := sm.GetOrCreateStaker(staker)

	// Begin atomic operation
	oldTotalStaked := stakerState.TotalStaked
	oldDelegation, hasDelegation := stakerState.Delegations[delegatee]

	// Calculate new delegation amount
	var newAmount uint64
	if isIncrease {
		if hasDelegation {
			newAmount = oldDelegation.Amount + amount
		} else {
			newAmount = amount
		}
	} else {
		if !hasDelegation {
			return ErrDelegationNotFound
		}
		if oldDelegation.Amount < amount {
			return ErrInsufficientBalance
		}
		newAmount = oldDelegation.Amount - amount
	}

	// Validate delegation
	if newAmount > 0 {
		// Update existing or create new
		if hasDelegation {
			// Check increment
			if isIncrease && amount < MIN_DELEGATION_INCREMENT {
				return ErrInsufficientIncrement
			}
		} else {
			// New delegation
			if newAmount < MIN_DELEGATION_PER_ADDRESS {
				return ErrInsufficientDelegation
			}
			if len(stakerState.Delegations) >= MAX_DELEGATIONS_PER_USER {
				return ErrTooManyDelegations
			}
		}

		// Update delegation
		stakerState.Delegations[delegatee] = DelegationInfo{
			Amount:     newAmount,
			StartEpoch: currentEpoch,
		}
	} else {
		// Remove delegation
		delete(stakerState.Delegations, delegatee)
	}

	// Update total staked
	if isIncrease {
		stakerState.TotalStaked += amount
		sm.totalStaked += amount
	} else {
		stakerState.TotalStaked -= amount
		sm.totalStaked -= amount
	}

	// Update voting power
	deltaAmount := int64(amount)
	if !isIncrease {
		deltaAmount = -deltaAmount
	}

	err := sm.votingManager.UpdateVotingPower(delegatee, staker, deltaAmount, currentEpoch)
	if err != nil {
		// Rollback on error
		stakerState.TotalStaked = oldTotalStaked
		if hasDelegation {
			stakerState.Delegations[delegatee] = oldDelegation
		} else {
			delete(stakerState.Delegations, delegatee)
		}
		if isIncrease {
			sm.totalStaked -= amount
		} else {
			sm.totalStaked += amount
		}
		return err
	}

	// Update last update epoch
	stakerState.LastUpdateEpoch = currentEpoch

	// Update staker in tree
	sm.stakers.Set(staker.String(), stakerState)

	return nil
}

// ProcessRewards processes rewards for a staker
func (sm *StakerManager) ProcessRewards(staker std.Address) (gnsReward uint64, protocolFees map[string]uint64, err error) {
	stakerState := sm.GetStaker(staker)
	if stakerState == nil {
		return 0, nil, ErrStakerNotFound
	}

	currentEpoch := sm.epochManager.GetCurrentEpoch()

	// Claim rewards through reward manager
	gnsReward, protocolFees = sm.rewardManager.ClaimReward(stakerState, currentEpoch)

	// Update staker state
	sm.stakers.Set(staker.String(), stakerState)

	return gnsReward, protocolFees, nil
}

// AddLocked adds locked GNS for a staker (from undelegation)
func (sm *StakerManager) AddLocked(staker std.Address, amount uint64, unlockTime int64) error {
	stakerState := sm.GetStaker(staker)
	if stakerState == nil {
		return ErrStakerNotFound
	}

	// Add locked info
	stakerState.LockedGNS = append(stakerState.LockedGNS, LockedGNSInfo{
		Amount:     amount,
		UnlockTime: unlockTime,
	})

	// Update staker in tree
	sm.stakers.Set(staker.String(), stakerState)

	return nil
}

// CollectUnlocked collects unlocked GNS for a staker
func (sm *StakerManager) CollectUnlocked(staker std.Address, currentTime int64) (uint64, error) {
	stakerState := sm.GetStaker(staker)
	if stakerState == nil {
		return 0, ErrStakerNotFound
	}

	var totalUnlocked uint64
	var remainingLocked []LockedGNSInfo

	for _, locked := range stakerState.LockedGNS {
		if currentTime >= locked.UnlockTime {
			totalUnlocked += locked.Amount
		} else {
			remainingLocked = append(remainingLocked, locked)
		}
	}

	// Update locked list
	stakerState.LockedGNS = remainingLocked

	// Update staker in tree
	sm.stakers.Set(staker.String(), stakerState)

	return totalUnlocked, nil
}

// GetTotalStaked returns the total amount staked across all stakers
func (sm *StakerManager) GetTotalStaked() uint64 {
	return sm.totalStaked
}

// GetStakerInfo returns detailed information about a staker
func (sm *StakerManager) GetStakerInfo(address std.Address) *StakerInfo {
	staker := sm.GetStaker(address)
	if staker == nil {
		return nil
	}

	// Calculate pending rewards
	currentEpoch := sm.epochManager.GetCurrentEpoch()
	gnsReward, protocolFees := sm.rewardManager.CalculatePendingReward(staker, currentEpoch)

	// Convert delegations map to list
	delegations := make([]DelegationDetails, 0, len(staker.Delegations))
	for delegatee, info := range staker.Delegations {
		delegations = append(delegations, DelegationDetails{
			Delegatee:  delegatee,
			Amount:     info.Amount,
			StartEpoch: info.StartEpoch,
		})
	}

	// Calculate total locked
	var totalLocked uint64
	for _, locked := range staker.LockedGNS {
		totalLocked += locked.Amount
	}

	return &StakerInfo{
		Address:     staker.Address,
		TotalStaked: staker.TotalStaked,
		TotalLocked: totalLocked,
		Delegations: delegations,
		PendingGNS:  gnsReward,
		PendingFees: protocolFees,
		LastUpdate:  staker.LastUpdateEpoch,
	}
}

// TransitionEpoch updates all stakers for epoch transition
func (sm *StakerManager) TransitionEpoch(newEpoch uint64) {
	// Update reward manager with current total staked
	epochState := sm.rewardManager.GetOrCreateEpoch(newEpoch)
	epochState.TotalStaked = sm.totalStaked
}

// StakerInfo represents public staker information
type StakerInfo struct {
	Address     std.Address
	TotalStaked uint64
	TotalLocked uint64
	Delegations []DelegationDetails
	PendingGNS  uint64
	PendingFees map[string]uint64
	LastUpdate  uint64
}

// DelegationDetails represents delegation information for external queries
type DelegationDetails struct {
	Delegatee  std.Address
	Amount     uint64
	StartEpoch uint64
}
