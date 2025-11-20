package launchpad

import (
	"gno.land/p/nt/ufmt"
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
// - recipient (std.Address): The address to receive the project's rewards.
// - conditions (map[string]*ProjectCondition): A map of token paths to their associated conditions.
// - tiers (map[int64]*ProjectTier): A map of tier durations to their associated tiers.
// - tiersRatios (map[int64]int64): A map of tier durations to their associated ratios.
// - createdBlockTimeInfo (BlockTimeInfo): The block time and height information for the creation of the project.
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

// GetID returns the ID of the project.
func (p *Project) ID() string {
	return p.id
}

// SetID sets the ID of the project.
func (p *Project) SetID(id string) {
	p.id = id
}

// GetName returns the name of the project.
func (p *Project) Name() string {
	return p.name
}

// SetName sets the name of the project.
func (p *Project) SetName(name string) {
	p.name = name
}

// GetTokenPath returns the token path of the project.
func (p *Project) TokenPath() string {
	return p.tokenPath
}

// SetTokenPath sets the token path of the project.
func (p *Project) SetTokenPath(tokenPath string) {
	p.tokenPath = tokenPath
}

// GetDepositAmount returns the deposit amount of the project.
func (p *Project) DepositAmount() int64 {
	return p.depositAmount
}

// SetDepositAmount sets the deposit amount of the project.
func (p *Project) SetDepositAmount(amount int64) {
	p.depositAmount = amount
}

// GetRecipient returns the recipient address of the project.
func (p *Project) Recipient() address {
	return p.recipient
}

// SetRecipient sets the recipient address of the project.
func (p *Project) SetRecipient(recipient address) {
	p.recipient = recipient
}

// GetConditions returns the conditions map of the project.
func (p *Project) Conditions() map[string]*ProjectCondition {
	return p.conditions
}

// SetConditions sets the conditions map of the project.
func (p *Project) SetConditions(conditions map[string]*ProjectCondition) {
	p.conditions = conditions
}

// GetTiers returns the tiers map of the project.
func (p *Project) Tiers() map[int64]*ProjectTier {
	return p.tiers
}

// SetTiers sets the tiers map of the project.
func (p *Project) SetTiers(tiers map[int64]*ProjectTier) {
	p.tiers = tiers
}

// GetTiersRatios returns the tiers ratios map of the project.
func (p *Project) TiersRatios() map[int64]int64 {
	return p.tiersRatios
}

// SetTiersRatios sets the tiers ratios map of the project.
func (p *Project) SetTiersRatios(tiersRatios map[int64]int64) {
	p.tiersRatios = tiersRatios
}

// GetCreatedHeight returns the created height of the project.
func (p *Project) CreatedHeight() int64 {
	return p.createdHeight
}

// SetCreatedHeight sets the created height of the project.
func (p *Project) SetCreatedHeight(height int64) {
	p.createdHeight = height
}

// GetCreatedAt returns the created time of the project.
func (p *Project) CreatedAt() int64 {
	return p.createdAt
}

// SetCreatedAt sets the created time of the project.
func (p *Project) SetCreatedAt(time int64) {
	p.createdAt = time
}

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
		createdHeight: createdHeight,
		createdAt:     createdAt,
	}
}

// MakeProjectID generates a unique project ID based on the given token path and the current block height.
//
// The generated ID combines the `tokenPath` and the current block height in the following format:
// "{tokenPath}:{height}"
//
// Parameters:
// - tokenPath (string): The path of the token associated with the project.
//
// Returns:
// - string: A unique project ID in the format "tokenPath:height".
func MakeProjectID(tokenPath string, createdHeight int64) string {
	return ufmt.Sprintf("%s:%d", tokenPath, createdHeight)
}
