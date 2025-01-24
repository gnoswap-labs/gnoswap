package launchpad

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// region: Project

type Project struct {
	id            string // 'tokenPath:createdHeight'
	name          string
	tokenPath     string
	depositAmount uint64
	recipient     std.Address          // string

	conditions    map[string]Condition // tokenPath -> Condition
	tiers         map[uint64]Tier
	tiersRatios   map[uint64]uint64

	created       TimeInfo
	started       TimeInfo
	ended         TimeInfo // same with tier 180's data

	stats         projectStats
	refund        RefundInfo
}

// getters and setters

func (p *Project) ID() string { return p.id }
func (p *Project) SetID(v string) { p.id = v }
func (p *Project) Name() string { return p.name }
func (p *Project) SetName(v string) { p.name = v }
func (p *Project) TokenPath() string { return p.tokenPath }
func (p *Project) SetTokenPath(v string) { p.tokenPath = v }
func (p *Project) DepositAmount() uint64 { return p.depositAmount }
func (p *Project) SetDepositAmount(v uint64) { p.depositAmount = v }
func (p *Project) Recipient() std.Address { return p.recipient }
func (p *Project) SetRecipient(v std.Address) { p.recipient = v }

func (p *Project) Conditions() map[string]Condition { return p.conditions }
func (p *Project) SetConditions(v map[string]Condition) { p.conditions = v }
func (p *Project) Tiers() map[uint64]Tier { return p.tiers }
func (p *Project) SetTiers(v map[uint64]Tier) { p.tiers = v }

// XXX: I think these are not needed.
func (p *Project) TiersRatios() map[uint64]uint64 { return p.tiersRatios }
func (p *Project) SetTiersRatios(v map[uint64]uint64) { p.tiersRatios = v }

func (p *Project) Created() TimeInfo { return p.created }
func (p *Project) SetCreated(v TimeInfo) { p.created = v }
func (p *Project) Started() TimeInfo { return p.started }
func (p *Project) SetStarted(v TimeInfo) { p.started = v }
func (p *Project) Ended() TimeInfo { return p.ended }
func (p *Project) SetEnded(v TimeInfo) { p.ended = v }

func (p *Project) Stats() projectStats { return p.stats }
func (p *Project) SetStats(v projectStats) { p.stats = v }
func (p *Project) Refund() RefundInfo { return p.refund }
func (p *Project) SetRefund(v RefundInfo) { p.refund = v }

// NewProject creates a new Project instance.
func NewProject(
	id, name, tokenPath string,
	depositAmount uint64,
	recipient std.Address,
	conditions map[string]Condition,
	tiers map[uint64]Tier,
	tiersRatios map[uint64]uint64,
	created, started, ended TimeInfo,
	stats projectStats,
	refund RefundInfo,
) *Project {
	return &Project{
		id:            id,
		name:          name,
		tokenPath:     tokenPath,
		depositAmount: depositAmount,
		recipient:     recipient,
		conditions:    conditions,
		tiers:         tiers,
		tiersRatios:   tiersRatios,
		created:       created,
		started:       started,
		ended:         ended,
		stats:         stats,
		refund:        refund,
	}
}

func (p *Project) Tier(key uint64) (Tier, error) {
	tier, exists := p.tiers[key]
	if !exists {
		return Tier{}, ufmt.Errorf("tier(%s) not found", key)
	}
	return tier, nil
}

func (p *Project) MustTier(key uint64) Tier {
	tier, err := p.Tier(key)
	if err != nil {
		panic(err)
	}
	return tier
}

func (p *Project) IsActivated(currentHeight uint64) bool {
	return p.started.Height() <= currentHeight && currentHeight < p.ended.Height()
}

func (p *Project) LeftReward() uint64 {
	return p.DepositAmount() - p.Stats().totalCollected
}

// region: projectStates

// projectStats is a struct that holds the statistics of a project.
type projectStats struct {
	totalDeposit      uint64 // won't be decreased
	actualDeposit     uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalParticipant  uint64 // accu, won't be decreased
	actualParticipant uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalCollected    uint64 // collect reward amount
}

// getters and setters

func (ps *projectStats) TotalDeposit() uint64 { return ps.totalDeposit }
func (ps *projectStats) SetTotalDeposit(v uint64) { ps.totalDeposit = v }
func (ps *projectStats) ActualDeposit() uint64 { return ps.actualDeposit }
func (ps *projectStats) SetActualDeposit(v uint64) { ps.actualDeposit = v }
func (ps *projectStats) TotalParticipant() uint64 { return ps.totalParticipant }
func (ps *projectStats) SetTotalParticipant(v uint64) { ps.totalParticipant = v }
func (ps *projectStats) ActualParticipant() uint64 { return ps.actualParticipant }
func (ps *projectStats) SetActualParticipant(v uint64) { ps.actualParticipant = v }
func (ps *projectStats) TotalCollected() uint64 { return ps.totalCollected }
func (ps *projectStats) SetTotalCollected(v uint64) { ps.totalCollected = v }

// newProjectStats returns a pointer to a new ProjectStats with the given values.
func newProjectStats(
	totalDeposit, actualDeposit, totalParticipant, actualParticipant, totalCollected uint64,
) *projectStats {
	return &projectStats{
		totalDeposit:      totalDeposit,
		actualDeposit:     actualDeposit,
		totalParticipant:  totalParticipant,
		actualParticipant: actualParticipant,
		totalCollected:    totalCollected,
	}
}
