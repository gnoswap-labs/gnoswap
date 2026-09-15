package launchpad

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Project represents a launchpad project.
//
// This struct contains the necessary data and methods to manage and distribute
// rewards for a specific project.
//
// Fields:
// - id (string): The unique identifier for the project, formatted as "{tokenPath}:{createdHeight}".
// - name (string): The name of the project.
// - tokenPath (string): The path of the token associated with the project.
// - depositAmount (int64): The total amount of tokens deposited for the project.
// - recipient (address): The address to receive the project's rewards.
// - conditions (map[string]*ProjectCondition): A map of token paths to their associated conditions.
// - tiers (map[int64]*ProjectTier): A map of tier durations to their associated tiers.
// - tiersRatios (map[int64]int64): A map of tier durations to their associated ratios.
// - createdHeight (int64): The block height at which the project was created.
// - createdAt (int64): The Unix timestamp at which the project was created.
type Project struct {
	id            string // 'tokenPath:createdHeight'
	name          string
	tokenPath     string
	depositAmount int64
	recipient     address                      // string
	conditions    map[string]*ProjectCondition // tokenPath -> Condition
	tiers         map[int64]*ProjectTier
	tiersRatios   map[int64]int64
	createdHeight int64
	createdAt     int64
}

// ID returns the project identifier in "{tokenPath}:{createdHeight}" form.
//
// Returns:
//   - id: unique identifier assigned to this project.
func (p *Project) ID() string {
	return p.id
}

// SetID replaces the project's identifier.
//
// Parameters:
//   - id: project identifier to store, normally in "{tokenPath}:{createdHeight}" form.
func (p *Project) SetID(id string) {
	p.id = id
}

// Name returns the project's human-readable name.
//
// Returns:
//   - name: stored project name.
func (p *Project) Name() string {
	return p.name
}

// SetName replaces the project's human-readable name.
//
// Parameters:
//   - name: project name to store.
func (p *Project) SetName(name string) {
	p.name = name
}

// TokenPath returns the token path whose tokens are distributed as project rewards.
//
// Returns:
//   - tokenPath: configured project reward-token path.
func (p *Project) TokenPath() string {
	return p.tokenPath
}

// SetTokenPath replaces the project's reward-token path.
//
// Parameters:
//   - tokenPath: token path to store as the project's reward token.
func (p *Project) SetTokenPath(tokenPath string) {
	p.tokenPath = tokenPath
}

// DepositAmount returns the total reward-token allocation configured for the project.
//
// Returns:
//   - amount: project reward-token allocation.
func (p *Project) DepositAmount() int64 {
	return p.depositAmount
}

// SetDepositAmount replaces the project's total reward-token allocation.
//
// Parameters:
//   - amount: total reward-token amount allocated to the project.
func (p *Project) SetDepositAmount(amount int64) {
	p.depositAmount = amount
}

// Recipient returns the address authorized to receive the project's rewards.
//
// Returns:
//   - recipient: configured project recipient address.
func (p *Project) Recipient() address {
	return p.recipient
}

// SetRecipient replaces the address authorized to receive project rewards.
//
// Parameters:
//   - recipient: address to store as the project recipient.
func (p *Project) SetRecipient(recipient address) {
	p.recipient = recipient
}

// Conditions returns a copy of the project's token deposit conditions.
//
// Returns:
//   - conditions: map from token path to cloned condition values; mutations do not alter project state.
func (p *Project) Conditions() map[string]*ProjectCondition {
	conditions := make(map[string]*ProjectCondition)

	for tokenPath, condition := range p.conditions {
		conditions[tokenPath] = condition.Clone()
	}

	return conditions
}

// SetConditions replaces the project's token deposit conditions.
// The map and its entries are retained in the project realm for later mutation.
//
// Parameters:
//   - conditions: map from required token path to its deposit condition.
func (p *Project) SetConditions(conditions map[string]*ProjectCondition) {
	owned := make(map[string]*ProjectCondition, len(conditions))
	for tokenPath, condition := range conditions {
		owned[tokenPath] = condition
	}
	p.conditions = owned
}

// SetCondition replaces one token-path deposit condition in the project-owned map.
//
// Parameters:
//   - tokenPath: token path whose condition is replaced.
//   - condition: required balance condition for that token path.
func (p *Project) SetCondition(tokenPath string, condition *ProjectCondition) {
	p.conditions[tokenPath] = condition
}

// Tiers returns a copy of the project's configured duration-to-tier map.
//
// Returns:
//   - tiers: map from tier duration in seconds to cloned tier values.
func (p *Project) Tiers() map[int64]*ProjectTier {
	tiers := make(map[int64]*ProjectTier)

	for duration, tier := range p.tiers {
		tiers[duration] = tier.Clone()
	}

	return tiers
}

// SetTiers replaces the project's tier map with a project-owned map.
//
// Parameters:
//   - tiers: map from tier duration in seconds to its tier configuration.
func (p *Project) SetTiers(tiers map[int64]*ProjectTier) {
	owned := make(map[int64]*ProjectTier, len(tiers))
	for duration, tier := range tiers {
		owned[duration] = tier
	}
	p.tiers = owned
}

// TiersRatios returns reward allocation ratios keyed by tier duration.
//
// Returns:
//   - ratios: map from tier duration in seconds to its allocation ratio.
func (p *Project) TiersRatios() map[int64]int64 {
	return p.tiersRatios
}

// SetTiersRatios replaces the project's tier allocation ratios.
//
// Parameters:
//   - tiersRatios: map from tier duration in seconds to its reward allocation ratio.
func (p *Project) SetTiersRatios(tiersRatios map[int64]int64) {
	p.tiersRatios = tiersRatios
}

// CreatedHeight returns the block height at which the project was created.
//
// Returns:
//   - height: project creation block height.
func (p *Project) CreatedHeight() int64 {
	return p.createdHeight
}

// SetCreatedHeight replaces the project's creation block height.
//
// Parameters:
//   - height: block height to store as the project creation height.
func (p *Project) SetCreatedHeight(height int64) {
	p.createdHeight = height
}

// CreatedAt returns the Unix timestamp at which the project was created.
//
// Returns:
//   - time: project creation Unix timestamp.
func (p *Project) CreatedAt() int64 {
	return p.createdAt
}

// SetCreatedAt replaces the project's creation timestamp.
//
// Parameters:
//   - time: Unix timestamp to store as the project creation time.
func (p *Project) SetCreatedAt(time int64) {
	p.createdAt = time
}

// GetTier returns a copy of the project's tier for one duration.
//
// Parameters:
//   - duration: tier duration in seconds.
//
// Returns:
//   - tier: cloned tier configuration for the duration, or nil when absent.
//   - err: non-nil when no tier is configured for duration.
func (p *Project) GetTier(duration int64) (*ProjectTier, error) {
	tier, exists := p.tiers[duration]
	if !exists {
		return nil, ufmt.Errorf("tier(%d) not found", duration)
	}

	return tier.Clone(), nil
}

// SetTier replaces one duration entry in the project-owned tier map.
//
// Parameters:
//   - duration: tier duration in seconds used as the map key.
//   - tier: tier configuration to store for duration.
func (p *Project) SetTier(duration int64, tier *ProjectTier) {
	p.tiers[duration] = tier
}

// IsRecipient reports whether recipient matches the project's configured recipient address.
//
// Parameters:
//   - recipient: address to compare with the configured project recipient.
//
// Returns:
//   - matches: true when recipient is the configured project recipient.
func (p *Project) IsRecipient(recipient address) bool {
	return p.recipient == recipient
}

// NewProject creates a project with empty conditions, tiers, and tier-ratio maps.
//
// Parameters:
//   - name: human-readable project name.
//   - tokenPath: token path whose tokens are distributed as project rewards.
//   - depositAmount: total reward-token amount allocated to the project.
//   - recipient: address authorized to receive project rewards.
//   - createdHeight: block height at which the project is created.
//   - createdAt: Unix timestamp at which the project is created.
//
// Returns:
//   - project: initialized project with an ID derived from tokenPath and createdHeight.
func NewProject(
	name string,
	tokenPath string,
	depositAmount int64,
	recipient address,
	createdHeight int64,
	createdAt int64,
) *Project {
	return &Project{
		id:            MakeProjectID(tokenPath, createdHeight),
		name:          name,
		tokenPath:     tokenPath,
		depositAmount: depositAmount,
		recipient:     recipient,
		conditions:    make(map[string]*ProjectCondition),
		tiers:         make(map[int64]*ProjectTier),
		tiersRatios:   make(map[int64]int64),
		createdHeight: createdHeight,
		createdAt:     createdAt,
	}
}

// Clone returns a deep-enough copy of the project for independent map and nested
// condition/tier mutation; scalar fields are copied directly.
//
// Returns:
//   - clone: project copy with independently allocated condition, tier, and ratio maps.
func (p Project) Clone() *Project {
	conditions := make(map[string]*ProjectCondition)
	for k, v := range p.conditions {
		conditions[k] = v.Clone()
	}

	tiers := make(map[int64]*ProjectTier)
	for k, v := range p.tiers {
		tiers[k] = v.Clone()
	}

	tiersRatios := make(map[int64]int64)
	for k, v := range p.tiersRatios {
		tiersRatios[k] = v
	}

	return &Project{
		id:            p.id,
		name:          p.name,
		tokenPath:     p.tokenPath,
		depositAmount: p.depositAmount,
		recipient:     p.recipient,
		conditions:    conditions,
		tiers:         tiers,
		tiersRatios:   tiersRatios,
		createdHeight: p.createdHeight,
		createdAt:     p.createdAt,
	}
}

// MakeProjectID combines a token path and creation height into a project identifier.
//
// Parameters:
//   - tokenPath: token path associated with the project.
//   - createdHeight: block height at which the project was created.
//
// Returns:
//   - projectID: identifier in "{tokenPath}:{createdHeight}" form.
func MakeProjectID(tokenPath string, createdHeight int64) string {
	return ufmt.Sprintf("%s:%d", tokenPath, createdHeight)
}
