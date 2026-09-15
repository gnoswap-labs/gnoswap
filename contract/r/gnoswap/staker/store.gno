package staker

import (
	"errors"

	"gno.land/p/gnoswap/store"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

// StoreKey.String returns the textual key used by the KV store.
//
// Returns:
//   - string: Underlying storage-key text.
func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyDepositGnsAmount                 StoreKey = "depositGnsAmount"
	StoreKeyMinimumRewardAmount              StoreKey = "minimumRewardAmount"
	StoreKeyDeposits                         StoreKey = "deposits"
	StoreKeyExternalIncentives               StoreKey = "externalIncentives"
	StoreKeyTotalEmissionSent                StoreKey = "totalEmissionSent"
	StoreKeyAllowedTokens                    StoreKey = "allowedTokens"
	StoreKeyDeniedRewardTokens               StoreKey = "deniedRewardTokens"
	StoreKeyIncentiveCounter                 StoreKey = "incentiveCounter"
	StoreKeyTokenSpecificMinimumRewards      StoreKey = "tokenSpecificMinimumRewards"
	StoreKeyUnstakingFee                     StoreKey = "unstakingFee"
	StoreKeyPendingProtocolFees              StoreKey = "pendingProtocolFees"
	StoreKeyUnstakedPositions                StoreKey = "unstakedPositions"
	StoreKeyUncollectedIncentiveCounts       StoreKey = "uncollectedIncentiveCounts"
	StoreKeyPools                            StoreKey = "pools"
	StoreKeyPoolTierMemberships              StoreKey = "poolTierMemberships"
	StoreKeyPoolTierRatio                    StoreKey = "poolTierRatio"
	StoreKeyPoolTierCounts                   StoreKey = "poolTierCounts"
	StoreKeyPoolTierLastRewardCacheTimestamp StoreKey = "poolTierLastRewardCacheTimestamp"
	StoreKeyPoolTierCurrentEmission          StoreKey = "poolTierCurrentEmission"
	StoreKeyPoolTierGetEmission              StoreKey = "poolTierGetEmission"
	StoreKeyPoolTierGetHalvingBlocksInRange  StoreKey = "poolTierGetHalvingBlocksInRange"
	StoreKeyWarmupTemplate                   StoreKey = "warmupTemplate"
	StoreKeyCurrentSwapBatch                 StoreKey = "currentSwapBatch"
)

type stakerStore struct {
	kvStore store.KVStore
}

// DepositGnsAmount
// HasDepositGnsAmountStoreKey reports whether the GNS reserve amount key exists.
//
// Returns:
//   - bool: True when a deposit GNS amount has been initialized in storage.
func (s *stakerStore) HasDepositGnsAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyDepositGnsAmount.String())
}

// GetDepositGnsAmount retrieves the GNS reserve amount deposited for the staker.
//
// Returns:
//   - int64: Stored GNS reserve amount; panics on read or type failure.
func (s *stakerStore) GetDepositGnsAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyDepositGnsAmount.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

// SetDepositGnsAmount stores the GNS amount deposited as the staker reserve.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - amount: GNS reserve amount used for staker initialization and accounting.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetDepositGnsAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDepositGnsAmount.String(), amount)
}

// MinimumRewardAmount
// HasMinimumRewardAmountStoreKey reports whether the default minimum-reward key exists.
//
// Returns:
//   - bool: True when the default minimum reward amount has been initialized in storage.
func (s *stakerStore) HasMinimumRewardAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyMinimumRewardAmount.String())
}

// GetMinimumRewardAmount retrieves the default minimum external reward amount.
//
// Returns:
//   - int64: Stored default minimum reward amount; panics on read or type failure.
func (s *stakerStore) GetMinimumRewardAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyMinimumRewardAmount.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

// SetMinimumRewardAmount stores the default minimum external reward amount.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - amount: Default minimum reward amount applied when no token-specific override exists.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetMinimumRewardAmount(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyMinimumRewardAmount.String(), amount)
}

// Deposits
// HasDepositsStoreKey reports whether the active-deposits key exists.
//
// Returns:
//   - bool: True when active deposits have been initialized in storage.
func (s *stakerStore) HasDepositsStoreKey() bool {
	return s.kvStore.Has(StoreKeyDeposits.String())
}

// GetDeposits retrieves the active deposit tree.
//
// Returns:
//   - *bptree.BPTree: Stored position-to-deposit records; panics on read or type failure.
func (s *stakerStore) GetDeposits() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyDeposits.String())
	if err != nil {
		panic(err)
	}

	deposits, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return deposits
}

// SetDeposits stores the deposit tree keyed by position identifier.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - deposits: B+ tree containing active staking deposits.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDeposits.String(), deposits)
}

// ExternalIncentives
// HasExternalIncentivesStoreKey reports whether the external-incentives key exists.
//
// Returns:
//   - bool: True when external incentives have been initialized in storage.
func (s *stakerStore) HasExternalIncentivesStoreKey() bool {
	return s.kvStore.Has(StoreKeyExternalIncentives.String())
}

// GetExternalIncentives retrieves the external incentive tree.
//
// Returns:
//   - *bptree.BPTree: Stored external incentive records; panics on read or type failure.
func (s *stakerStore) GetExternalIncentives() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyExternalIncentives.String())
	if err != nil {
		panic(err)
	}

	incentives, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return incentives
}

// SetExternalIncentives stores the external incentive tree.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - incentives: B+ tree mapping external incentive identifiers to incentive records.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetExternalIncentives(_ int, rlm realm, incentives *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyExternalIncentives.String(), incentives)
}

// TotalEmissionSent
// HasTotalEmissionSentStoreKey reports whether the total-emission-sent key exists.
//
// Returns:
//   - bool: True when cumulative sent emission has been initialized in storage.
func (s *stakerStore) HasTotalEmissionSentStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalEmissionSent.String())
}

// GetTotalEmissionSent retrieves the cumulative emission amount sent.
//
// Returns:
//   - int64: Stored cumulative emission amount; panics on read or type failure.
func (s *stakerStore) GetTotalEmissionSent() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalEmissionSent.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

// SetTotalEmissionSent stores the cumulative emission amount sent to staker pools.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - amount: Cumulative emission amount already sent.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetTotalEmissionSent(_ int, rlm realm, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTotalEmissionSent.String(), amount)
}

// AllowedTokens
// HasAllowedTokensStoreKey reports whether the allowed-token key exists.
//
// Returns:
//   - bool: True when the allowed external-reward token list has been initialized in storage.
func (s *stakerStore) HasAllowedTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyAllowedTokens.String())
}

// GetAllowedTokens retrieves a clone of the allowed external-reward token list.
//
// Returns:
//   - []string: Allowed token paths copied for the caller; panics on read or type failure.
func (s *stakerStore) GetAllowedTokens() []string {
	result, err := s.kvStore.Get(StoreKeyAllowedTokens.String())
	if err != nil {
		panic(err)
	}

	tokens, ok := result.([]string)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []string: %T", result))
	}

	return cloneStringSlice(tokens)
}

// SetAllowedTokens replaces the allowed external-reward token list.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokens: Registered token paths permitted as external reward tokens.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetAllowedTokens(_ int, rlm realm, tokens []string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAllowedTokens.String(), tokens)
}

// AddAllowedToken appends tokenPath to the allowed-tokens list when absent.
// The store-owned slice is cloned before mutation to avoid readonly-taint panics.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Registered token path to add to the allowed-token list.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) AddAllowedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	tokens := s.GetAllowedTokens()
	if !contains(tokens, tokenPath) {
		tokens = append(tokens, tokenPath)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAllowedTokens.String(), tokens)
}

// RemoveAllowedToken removes tokenPath from the allowed-tokens list when present.
// The store-owned slice is cloned before mutation to avoid readonly-taint panics.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Registered token path to remove from the allowed-token list.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) RemoveAllowedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	tokens := s.GetAllowedTokens()
	for i, t := range tokens {
		if t == tokenPath {
			tokens = append(tokens[:i], tokens[i+1:]...)
			break
		}
	}

	return s.kvStore.Set(0, rlm, StoreKeyAllowedTokens.String(), tokens)
}

// DeniedRewardTokens
//
// The deny list is the operational stop switch for the pool-pair reward-token
// policy: pair tokens qualify as external-incentive reward tokens without going
// through the governance allowlist (by design), so without this list there is
// no lever to stop NEW incentives in a pair token whose issuer turned hostile.
// A missing store key means an empty list, so no initializer seeding and no
// upgrade migration are needed.
// HasDeniedRewardTokensStoreKey reports whether the denied-reward-token key exists.
//
// Returns:
//   - bool: True when a denied-reward list has been initialized in storage.
func (s *stakerStore) HasDeniedRewardTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyDeniedRewardTokens.String())
}

// GetDeniedRewardTokens retrieves the denied-reward list, treating a missing key as empty.
//
// Returns:
//   - []string: Clone of denied reward-token paths; empty when the key is absent, and panics on read or type failure.
func (s *stakerStore) GetDeniedRewardTokens() []string {
	if !s.kvStore.Has(StoreKeyDeniedRewardTokens.String()) {
		return []string{}
	}

	result, err := s.kvStore.Get(StoreKeyDeniedRewardTokens.String())
	if err != nil {
		panic(err)
	}

	tokens, ok := result.([]string)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []string: %T", result))
	}

	return cloneStringSlice(tokens)
}

// AddDeniedRewardToken appends tokenPath to the denied-reward-tokens list when absent.
// The store-owned slice is cloned before mutation to avoid readonly-taint panics.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Reward-token path to block for new external incentives.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) AddDeniedRewardToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	tokens := s.GetDeniedRewardTokens()
	if !contains(tokens, tokenPath) {
		tokens = append(tokens, tokenPath)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDeniedRewardTokens.String(), tokens)
}

// RemoveDeniedRewardToken removes tokenPath from the denied-reward-tokens list when present.
// The store-owned slice is cloned before mutation to avoid readonly-taint panics.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Reward-token path to remove from the deny list.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) RemoveDeniedRewardToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	tokens := s.GetDeniedRewardTokens()
	for i, t := range tokens {
		if t == tokenPath {
			tokens = append(tokens[:i], tokens[i+1:]...)
			break
		}
	}

	return s.kvStore.Set(0, rlm, StoreKeyDeniedRewardTokens.String(), tokens)
}

// IncentiveCounter
// HasIncentiveCounterStoreKey reports whether the incentive-counter key exists.
//
// Returns:
//   - bool: True when an incentive counter has been initialized in storage.
func (s *stakerStore) HasIncentiveCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyIncentiveCounter.String())
}

// GetIncentiveCounter retrieves the persistent incentive identifier counter.
//
// Returns:
//   - *Counter: Stored counter state; panics on read or type failure.
func (s *stakerStore) GetIncentiveCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyIncentiveCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Counter: %T", result))
	}

	return counter
}

// SetIncentiveCounter stores the counter used to allocate incentive identifiers.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - counter: Counter state whose next value is used by NextIncentiveID.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetIncentiveCounter(_ int, rlm realm, counter *Counter) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyIncentiveCounter.String(), counter)
}

// NextIncentiveID advances the stored counter and builds a unique incentive identifier.
//
// Parameters:
//   - creator: Address that created the incentive.
//   - timestamp: Incentive start or creation timestamp included in the identifier.
//
// Returns:
//   - string: Identifier combining creator, timestamp, and the next counter index.
func (s *stakerStore) NextIncentiveID(creator address, timestamp int64) string {
	counter := s.GetIncentiveCounter()
	return makeIncentiveID(creator, timestamp, counter.Next())
}

// TokenSpecificMinimumRewards
// HasTokenSpecificMinimumRewardsStoreKey reports whether the token-specific minimum-rewards key exists.
//
// Returns:
//   - bool: True when token-specific minimum rewards have been initialized in storage.
func (s *stakerStore) HasTokenSpecificMinimumRewardsStoreKey() bool {
	return s.kvStore.Has(StoreKeyTokenSpecificMinimumRewards.String())
}

// GetTokenSpecificMinimumRewards retrieves per-token minimum reward amounts.
//
// Returns:
//   - map[string]int64: Stored minimum reward overrides keyed by token path; panics on read or type failure.
func (s *stakerStore) GetTokenSpecificMinimumRewards() map[string]int64 {
	result, err := s.kvStore.Get(StoreKeyTokenSpecificMinimumRewards.String())
	if err != nil {
		panic(err)
	}

	rewards, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to map[string]int64: %T", result))
	}

	return rewards
}

// SetTokenSpecificMinimumRewards replaces the token-specific minimum reward map.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - rewards: Minimum reward amounts keyed by token path.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetTokenSpecificMinimumRewards(_ int, rlm realm, rewards map[string]int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTokenSpecificMinimumRewards.String(), rewards)
}

// SetTokenSpecificMinimumRewardItem sets a single token's minimum reward amount.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Token path receiving the minimum reward override.
//   - amount: Minimum reward amount required for tokenPath.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	rewards := s.GetTokenSpecificMinimumRewards()

	owned := make(map[string]int64)
	for k, v := range rewards {
		owned[k] = v
	}

	owned[tokenPath] = amount

	return s.kvStore.Set(0, rlm, StoreKeyTokenSpecificMinimumRewards.String(), owned)
}

// RemoveTokenSpecificMinimumRewardItem removes a single token's minimum reward entry.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - tokenPath: Token path whose override is removed.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) RemoveTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	rewards := s.GetTokenSpecificMinimumRewards()

	owned := make(map[string]int64)
	for k, v := range rewards {
		if k == tokenPath {
			continue
		}

		owned[k] = v
	}

	return s.kvStore.Set(0, rlm, StoreKeyTokenSpecificMinimumRewards.String(), owned)
}

// UnstakingFee
// HasUnstakingFeeStoreKey reports whether the unstaking-fee key exists.
//
// Returns:
//   - bool: True when an unstaking fee has been initialized in storage.
func (s *stakerStore) HasUnstakingFeeStoreKey() bool {
	return s.kvStore.Has(StoreKeyUnstakingFee.String())
}

// GetUnstakingFee retrieves the configured unstaking fee rate.
//
// Returns:
//   - uint64: Stored unstaking fee rate in basis points; panics on read or type failure.
func (s *stakerStore) GetUnstakingFee() uint64 {
	result, err := s.kvStore.Get(StoreKeyUnstakingFee.String())
	if err != nil {
		panic(err)
	}

	fee, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return fee
}

// SetUnstakingFee stores the fee charged when a position is unstaked.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - fee: Unstaking fee rate in basis points.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetUnstakingFee(_ int, rlm realm, fee uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUnstakingFee.String(), fee)
}

// HasPendingProtocolFeesStoreKey reports whether the pending protocol-fees key exists.
//
// Returns:
//   - bool: True when pending protocol fees have been initialized in storage.
func (s *stakerStore) HasPendingProtocolFeesStoreKey() bool {
	return s.kvStore.Has(StoreKeyPendingProtocolFees.String())
}

// GetPendingProtocolFees retrieves pending protocol fee amounts keyed by token path.
//
// Returns:
//   - map[string]int64: Stored token-to-fee map; panics on read or type failure.
func (s *stakerStore) GetPendingProtocolFees() map[string]int64 {
	result, err := s.kvStore.Get(StoreKeyPendingProtocolFees.String())
	if err != nil {
		panic(err)
	}

	fees, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to map[string]int64: %T", result))
	}

	return fees
}

// SetPendingProtocolFees replaces the pending protocol-fee map with a store-owned copy.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - fees: Pending protocol fee amounts keyed by token path.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	// The map is copied here so it is allocated by, and therefore mutable from, this realm.
	owned := make(map[string]int64, len(fees))
	for tokenPath, amount := range fees {
		owned[tokenPath] = amount
	}

	return s.kvStore.Set(0, rlm, StoreKeyPendingProtocolFees.String(), owned)
}

// GetPendingProtocolFee returns one token's pending protocol fee amount.
//
// Parameters:
//   - tokenPath: Token path whose pending fee is read.
//
// Returns:
//   - int64: Stored pending fee amount, or zero when tokenPath has no map entry.
func (s *stakerStore) GetPendingProtocolFee(tokenPath string) int64 {
	return s.GetPendingProtocolFees()[tokenPath]
}

// SetPendingProtocolFee updates one token's pending protocol fee in the stored fee map.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context and write-authorizing realm.
//   - tokenPath: Token path whose pending fee amount is updated.
//   - amount: Pending protocol fee amount for tokenPath.
//
// Returns:
//   - error: ErrSpoofedRealm or write-permission error when the realm cannot mutate this store; nil on success.
func (s *stakerStore) SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	s.GetPendingProtocolFees()[tokenPath] = amount

	return nil
}

// RemovePendingProtocolFee removes one token's pending protocol fee entry.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context and write-authorizing realm.
//   - tokenPath: Token path whose pending fee entry is deleted.
//
// Returns:
//   - error: ErrSpoofedRealm or write-permission error when the realm cannot mutate this store; nil on success.
func (s *stakerStore) RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	delete(s.GetPendingProtocolFees(), tokenPath)

	return nil
}

// UnstakedPositions
// HasUnstakedPositionsStoreKey reports whether the unstaked-positions key exists.
//
// Returns:
//   - bool: True when unstaked positions have been initialized in storage.
func (s *stakerStore) HasUnstakedPositionsStoreKey() bool {
	return s.kvStore.Has(StoreKeyUnstakedPositions.String())
}

// GetUnstakedPositions retrieves the unstaked-position tree.
//
// Returns:
//   - *bptree.BPTree: Stored unstaked-position records; panics on read or type failure.
func (s *stakerStore) GetUnstakedPositions() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyUnstakedPositions.String())
	if err != nil {
		panic(err)
	}

	positions, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return positions
}

// SetUnstakedPositions stores positions that have been unstaked but retain reward checkpoints.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - positions: B+ tree of unstaked position records and their exit checkpoints.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetUnstakedPositions(_ int, rlm realm, positions *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUnstakedPositions.String(), positions)
}

// UncollectedIncentiveCounts
// HasUncollectedIncentiveCountsStoreKey reports whether the uncollected-counts key exists.
//
// Returns:
//   - bool: True when uncollected incentive counts have been initialized in storage.
func (s *stakerStore) HasUncollectedIncentiveCountsStoreKey() bool {
	return s.kvStore.Has(StoreKeyUncollectedIncentiveCounts.String())
}

// GetUncollectedIncentiveCounts retrieves outstanding-position counts by incentive.
//
// Returns:
//   - *bptree.BPTree: Stored incentive-to-count tree; panics on read or type failure.
func (s *stakerStore) GetUncollectedIncentiveCounts() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyUncollectedIncentiveCounts.String())
	if err != nil {
		panic(err)
	}

	counts, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return counts
}

// SetUncollectedIncentiveCounts stores counts of unstaked positions owing each incentive.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - counts: B+ tree mapping incentive identifiers to outstanding position counts.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetUncollectedIncentiveCounts(_ int, rlm realm, counts *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUncollectedIncentiveCounts.String(), counts)
}

// Pools
// HasPoolsStoreKey reports whether the pools key exists.
//
// Returns:
//   - bool: True when the pool collection has been initialized in storage.
func (s *stakerStore) HasPoolsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPools.String())
}

// GetPools retrieves the staker's pool collection.
//
// Returns:
//   - *bptree.BPTree: Stored pool tree; panics on read or type failure.
func (s *stakerStore) GetPools() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyPools.String())
	if err != nil {
		panic(err)
	}

	pools, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return pools
}

// SetPools stores the pool collection used by the staker.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - pools: Pool tree containing registered pools and their reward state.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPools(_ int, rlm realm, pools *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPools.String(), pools)
}

// PoolTierMemberships
// HasPoolTierMembershipsStoreKey reports whether the pool-tier membership key exists.
//
// Returns:
//   - bool: True when pool-tier memberships have been initialized in storage.
func (s *stakerStore) HasPoolTierMembershipsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierMemberships.String())
}

// GetPoolTierMemberships retrieves the pool-to-tier membership tree.
//
// Returns:
//   - *bptree.BPTree: Stored mapping from pool paths to tier numbers; panics on read or type failure.
func (s *stakerStore) GetPoolTierMemberships() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyPoolTierMemberships.String())
	if err != nil {
		panic(err)
	}

	memberships, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return memberships
}

// SetPoolTierMemberships stores the pool-to-tier membership tree.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - memberships: Mapping from pool paths to their assigned tier numbers.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierMemberships(_ int, rlm realm, memberships *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierMemberships.String(), memberships)
}

// PoolTierRatio
// HasPoolTierRatioStoreKey reports whether the pool-tier ratio key exists.
//
// Returns:
//   - bool: True when a pool-tier ratio has been initialized in storage.
func (s *stakerStore) HasPoolTierRatioStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierRatio.String())
}

// GetPoolTierRatio retrieves the configured pool-tier reward-share ratio.
//
// Returns:
//   - TierRatio: Stored ratio distribution across tiers; panics on read or type failure.
func (s *stakerStore) GetPoolTierRatio() TierRatio {
	result, err := s.kvStore.Get(StoreKeyPoolTierRatio.String())
	if err != nil {
		panic(err)
	}

	ratio, ok := result.(TierRatio)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to TierRatio: %T", result))
	}

	return ratio
}

// SetPoolTierRatio stores the reward-share ratio for each pool tier.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - ratio: Tier reward-share ratio used to divide current emission.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierRatio(_ int, rlm realm, ratio TierRatio) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierRatio.String(), ratio)
}

// PoolTierCounts
// HasPoolTierCountsStoreKey reports whether the pool-tier counts key exists.
//
// Returns:
//   - bool: True when pool counts have been initialized in storage.
func (s *stakerStore) HasPoolTierCountsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierCounts.String())
}

// GetPoolTierCounts retrieves the pool count for every tier index.
//
// Returns:
//   - [AllTierCount]uint64: Stored pool counts indexed by tier; panics on read or type failure.
func (s *stakerStore) GetPoolTierCounts() [AllTierCount]uint64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierCounts.String())
	if err != nil {
		panic(err)
	}

	counts, ok := result.([AllTierCount]uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to [AllTierCount]uint64: %T", result))
	}

	return counts
}

// SetPoolTierCounts stores the number of pools assigned to each tier index.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - counts: Pool counts indexed by tier, including the reserved zero tier.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierCounts(_ int, rlm realm, counts [AllTierCount]uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierCounts.String(), counts)
}

// PoolTierLastRewardCacheTimestamp
// HasPoolTierLastRewardCacheTimestampStoreKey reports whether the tier reward-cache timestamp key exists.
//
// Returns:
//   - bool: True when a tier reward-cache timestamp has been initialized in storage.
func (s *stakerStore) HasPoolTierLastRewardCacheTimestampStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierLastRewardCacheTimestamp.String())
}

// GetPoolTierLastRewardCacheTimestamp retrieves the tier reward-cache timestamp.
//
// Returns:
//   - int64: Stored Unix timestamp through which tier rewards are materialized; panics on read or type failure.
func (s *stakerStore) GetPoolTierLastRewardCacheTimestamp() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierLastRewardCacheTimestamp.String())
	if err != nil {
		panic(err)
	}

	timestamp, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return timestamp
}

// SetPoolTierLastRewardCacheTimestamp stores the timestamp through which tier rewards are cached.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - timestamp: Unix timestamp through which pool-tier reward caches are materialized.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierLastRewardCacheTimestamp(_ int, rlm realm, timestamp int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierLastRewardCacheTimestamp.String(), timestamp)
}

// PoolTierCurrentEmission
// HasPoolTierCurrentEmissionStoreKey reports whether the current pool-tier emission key exists.
//
// Returns:
//   - bool: True when the current pool-tier emission has been initialized in storage.
func (s *stakerStore) HasPoolTierCurrentEmissionStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierCurrentEmission.String())
}

// GetPoolTierCurrentEmission retrieves the current pool-tier emission amount.
//
// Returns:
//   - int64: Stored emission amount used for tier reward accrual; panics on read or type failure.
func (s *stakerStore) GetPoolTierCurrentEmission() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierCurrentEmission.String())
	if err != nil {
		panic(err)
	}

	emission, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return emission
}

// SetPoolTierCurrentEmission stores the current pool-tier emission amount.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - emission: Current emission amount used for tier reward accrual.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierCurrentEmission(_ int, rlm realm, emission int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierCurrentEmission.String(), emission)
}

// PoolTierGetEmission
// HasPoolTierGetEmissionStoreKey reports whether the pool-tier emission callback key exists.
//
// Returns:
//   - bool: True when the current-emission callback has been initialized in storage.
func (s *stakerStore) HasPoolTierGetEmissionStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierGetEmission.String())
}

// GetPoolTierGetEmission retrieves the current-emission callback.
//
// Returns:
//   - func() (int64, error): Callback returning the current emission amount per second and an error; panics on read or type failure.
func (s *stakerStore) GetPoolTierGetEmission() func() (int64, error) {
	result, err := s.kvStore.Get(StoreKeyPoolTierGetEmission.String())
	if err != nil {
		panic(err)
	}

	fn, ok := result.(func() (int64, error))
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func() (int64, error): %T", result))
	}

	return fn
}

// SetPoolTierGetEmission stores the callback used to read current staker emission.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - fn: Callback returning the current emission amount per second and an error.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierGetEmission(_ int, rlm realm, fn func() (int64, error)) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierGetEmission.String(), fn)
}

// PoolTierGetHalvingBlocksInRange
// HasPoolTierGetHalvingBlocksInRangeStoreKey reports whether the pool-tier halving callback key exists.
//
// Returns:
//   - bool: True when the halving-range callback has been initialized in storage.
func (s *stakerStore) HasPoolTierGetHalvingBlocksInRangeStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierGetHalvingBlocksInRange.String())
}

// GetPoolTierGetHalvingBlocksInRange retrieves the stored halving-range callback.
//
// Returns:
//   - func(start, end int64) ([]int64, []int64, error): Callback returning halving timestamps and matching emissions for [start, end); panics on read or type failure.
func (s *stakerStore) GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64, error) {
	result, err := s.kvStore.Get(StoreKeyPoolTierGetHalvingBlocksInRange.String())
	if err != nil {
		panic(err)
	}

	fn, ok := result.(func(start, end int64) ([]int64, []int64, error))
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func(start, end int64) ([]int64, []int64, error): %T", result))
	}

	return fn
}

// SetPoolTierGetHalvingBlocksInRange stores the halving-range callback used by pool-tier reward caching.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - fn: Callback accepting [start, end) timestamps and returning halving timestamps, emissions, and an error.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetPoolTierGetHalvingBlocksInRange(_ int, rlm realm, fn func(start, end int64) ([]int64, []int64, error)) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolTierGetHalvingBlocksInRange.String(), fn)
}

// HasWarmupTemplateStoreKey reports whether the warmup-template key exists.
//
// Returns:
//   - bool: True when a warmup schedule has been initialized in storage.
func (s *stakerStore) HasWarmupTemplateStoreKey() bool {
	return s.kvStore.Has(StoreKeyWarmupTemplate.String())
}

// GetWarmupTemplate retrieves a clone of the stored warmup schedule.
//
// Returns:
//   - []Warmup: Warmup entries copied into the caller's realm; panics on read or type failure.
func (s *stakerStore) GetWarmupTemplate() []Warmup {
	result, err := s.kvStore.Get(StoreKeyWarmupTemplate.String())
	if err != nil {
		panic(err)
	}

	warmups, ok := result.([]Warmup)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []Warmup: %T", result))
	}

	return cloneWarmups(warmups)
}

// SetWarmupTemplate stores the warmup schedule used for external incentives.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - warmups: Warmup schedule entries to persist.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetWarmupTemplate(_ int, rlm realm, warmups []Warmup) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyWarmupTemplate.String(), warmups)
}

// CurrentSwapBatch
// HasCurrentSwapBatchStoreKey reports whether the current-swap-batch key exists.
//
// Returns:
//   - bool: True when the current swap batch has been initialized in storage.
func (s *stakerStore) HasCurrentSwapBatchStoreKey() bool {
	return s.kvStore.Has(StoreKeyCurrentSwapBatch.String())
}

// GetCurrentSwapBatch retrieves the processor for the currently active swap.
//
// Returns:
//   - *SwapBatchProcessor: Stored swap batch, or nil when initialization has recorded no active batch; panics on read or type failure.
func (s *stakerStore) GetCurrentSwapBatch() *SwapBatchProcessor {
	result, err := s.kvStore.Get(StoreKeyCurrentSwapBatch.String())
	if err != nil {
		panic(err)
	}

	batch, ok := result.(*SwapBatchProcessor)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *SwapBatchProcessor: %T", result))
	}

	return batch
}

// SetCurrentSwapBatch persists the processor for the currently active swap.
//
// Parameters:
//   - _: Leading realm-call discriminator for the forwarded store call; callers pass 0.
//   - rlm: Current staker realm context; it must be current before storage is written.
//   - batch: Swap-batch processor to persist, or nil when the swap has ended.
//
// Returns:
//   - error: ErrSpoofedRealm when rlm is not current, or the underlying KV-store write error; nil on success.
func (s *stakerStore) SetCurrentSwapBatch(_ int, rlm realm, batch *SwapBatchProcessor) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyCurrentSwapBatch.String(), batch)
}

// NewStakerStore creates a new staker store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
//
// Parameters:
//   - kvStore: Key-value store used for all staker state.
//
// Returns:
//   - IStakerStore: Store interface backed by the supplied KV store.
func NewStakerStore(kvStore store.KVStore) IStakerStore {
	return &stakerStore{
		kvStore: kvStore,
	}
}

func makeIncentiveID(creator address, timestamp int64, index int64) string {
	return ufmt.Sprintf("%s:%d:%d", creator.String(), timestamp, index)
}

func contains(items []string, item string) bool {
	for _, i := range items {
		if i == item {
			return true
		}
	}

	return false
}
