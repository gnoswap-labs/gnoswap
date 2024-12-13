package staker

var (
	/* internal */
	poolTiers = newPoolTiers()

	/* external */
	poolIncentives = newPoolIncentives()
	incentives = newIncentives()

	/* common */
	deposits = newDeposits()
)

// poolTiers stores internal tier information for each pool
type PoolTiers map[string]InternalTier

func newPoolTiers() PoolTiers {
	return make(PoolTiers)
}

func (p PoolTiers) Get(poolPath string) (InternalTier, bool) {
	internalTier, exist := p[poolPath]
	return internalTier, exist
}

func (p PoolTiers) Set(poolPath string, internalTier InternalTier) {
	p[poolPath] = internalTier
}

func (p PoolTiers) Remove(poolPath string) {
	delete(p, poolPath)
}

// poolIncentives maps pool paths to their associated incentive IDs
type PoolIncentives map[string][]string

func newPoolIncentives() PoolIncentives {
	return make(PoolIncentives)
}

func (p PoolIncentives) Get(poolPath string) ([]string, bool) {
	poolIncentives, exist := p[poolPath]
	return poolIncentives, exist
}

func (p PoolIncentives) Set(poolPath string, poolIncentives []string) {
	p[poolPath] = poolIncentives
}

type Incentives map[string]ExternalIncentive

func newIncentives() Incentives {
	return make(Incentives)
}

func (i Incentives) Get(incentiveId string) (ExternalIncentive, bool) {
	externalIncentive, exist := i[incentiveId]
	return externalIncentive, exist
}

func (i Incentives) Set(incentiveId string, externalIncentive ExternalIncentive) {
	i[incentiveId] = externalIncentive
}

func (i Incentives) Remove(incentiveId string) {
	delete(i, incentiveId)
}

// deposits stores deposit information for each tokenId
type Deposits map[uint64]Deposit

func newDeposits() Deposits {
	return make(Deposits)
}

func (d Deposits) Get(tokenId uint64) (Deposit, bool) {
	deposit, exist := d[tokenId]
	return deposit, exist
}

func (d Deposits) Set(tokenId uint64, deposit Deposit) {
	d[tokenId] = deposit
}

func (d Deposits) Remove(tokenId uint64) {
	delete(d, tokenId)
}

func (d Deposits) Iter(fn func(tokenId uint64, deposit Deposit)) {
	for tokenId, deposit := range d {
		fn(tokenId, deposit)
	}
}
