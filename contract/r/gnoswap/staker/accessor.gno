package staker

import (
	"errors"

	"gno.land/p/nt/grc721/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
)

type PoolAccessor interface {
	// ExistsPoolPath reports whether a pool is registered at poolPath.
	//
	// Parameters:
	//   - poolPath: Pool path whose registration is checked.
	//
	// Returns:
	//   - bool: true when a pool is registered at poolPath; false otherwise.
	ExistsPoolPath(poolPath string) bool
	// GetSlot0Tick returns the current slot-0 tick for a registered pool.
	//
	// Parameters:
	//   - poolPath: Pool path whose current tick is queried.
	//
	// Returns:
	//   - int32: Current signed slot-0 tick; the accessor panics if the underlying pool query fails.
	GetSlot0Tick(poolPath string) int32
	// GetSlot0SqrtPriceX96 returns a pool's current Q96-scaled square-root price.
	//
	// Parameters:
	//   - poolPath: Pool path whose current square-root price is queried.
	//
	// Returns:
	//   - string: Decimal representation of the Q96-scaled square-root price; the accessor panics if the underlying query fails.
	GetSlot0SqrtPriceX96(poolPath string) string

	// SetTickCrossHook registers a callback for pool tick-crossing events.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before the hook is registered.
	//   - hook: Callback invoked with the internal discriminator, current pool realm, pool path, crossed tick ID, swap direction (zeroForOne), and the event timestamp in Unix seconds.
	SetTickCrossHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))
	// SetSwapStartHook registers a callback invoked when a pool swap starts.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before the hook is registered.
	//   - hook: Callback invoked with the internal discriminator, current pool realm, pool path, and swap-start timestamp in Unix seconds.
	SetSwapStartHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, timestamp int64))
	// SetSwapEndHook registers a callback invoked when a pool swap ends.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before the hook is registered.
	//   - hook: Callback invoked with the internal discriminator, current pool realm, and pool path; its error is propagated by the pool hook.
	SetSwapEndHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string) error)
}

type poolAccessor struct{}

// ExistsPoolPath reports whether a pool is registered at poolPath.
//
// Parameters:
//   - poolPath: Pool path whose registration is checked.
//
// Returns:
//   - bool: true when a pool is registered at poolPath; false otherwise.
func (p *poolAccessor) ExistsPoolPath(poolPath string) bool {
	return pool.ExistsPoolPath(poolPath)
}

// GetSlot0Tick returns the current slot-0 tick for a registered pool.
//
// Parameters:
//   - poolPath: Pool path whose current tick is queried.
//
// Returns:
//   - int32: Current signed slot-0 tick; the accessor panics if the underlying pool query fails.
func (p *poolAccessor) GetSlot0Tick(poolPath string) int32 {
	tick, err := pool.GetSlot0Tick(poolPath)
	if err != nil {
		panic(err)
	}
	return tick
}

// GetSlot0SqrtPriceX96 returns a pool's current Q96-scaled square-root price.
//
// Parameters:
//   - poolPath: Pool path whose current square-root price is queried.
//
// Returns:
//   - string: Decimal representation of the Q96-scaled square-root price; the accessor panics if the underlying query fails.
func (p *poolAccessor) GetSlot0SqrtPriceX96(poolPath string) string {
	sqrtPriceX96, err := pool.GetSlot0SqrtPriceX96(poolPath)
	if err != nil {
		panic(err)
	}
	return sqrtPriceX96
}

// SetTickCrossHook registers a callback for pool tick-crossing events.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before the hook is registered.
//   - hook: Callback invoked with the internal discriminator, current pool realm, pool path, crossed tick ID, swap direction (zeroForOne), and the event timestamp in Unix seconds.
func (p *poolAccessor) SetTickCrossHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	access.AssertIsRlmCurrent(0, rlm)

	pool.SetTickCrossHook(cross(rlm), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		hook(0, cur, poolPath, tickId, zeroForOne, timestamp)
	})
}

// SetSwapStartHook registers a callback invoked when a pool swap starts.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before the hook is registered.
//   - hook: Callback invoked with the internal discriminator, current pool realm, pool path, and swap-start timestamp in Unix seconds.
func (p *poolAccessor) SetSwapStartHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, timestamp int64)) {
	access.AssertIsRlmCurrent(0, rlm)

	pool.SetSwapStartHook(cross(rlm), func(cur realm, poolPath string, timestamp int64) {
		hook(0, cur, poolPath, timestamp)
	})
}

// SetSwapEndHook registers a callback invoked when a pool swap ends.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before the hook is registered.
//   - hook: Callback invoked with the internal discriminator, current pool realm, and pool path; its error is propagated by the pool hook.
func (p *poolAccessor) SetSwapEndHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string) error) {
	access.AssertIsRlmCurrent(0, rlm)

	pool.SetSwapEndHook(cross(rlm), func(cur realm, poolPath string) error {
		return hook(0, cur, poolPath)
	})
}

// newPoolAccessor constructs the pool accessor used by staker implementations.
//
// Returns:
//   - PoolAccessor: Accessor that queries pool state and registers swap or tick hooks.
func newPoolAccessor() PoolAccessor {
	return &poolAccessor{}
}

type EmissionAccessor interface {
	// MintAndDistributeGns mints and distributes scheduled GNS emission through the emission realm.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before crossing into the emission realm.
	//
	// Returns:
	//   - int64: GNS amount distributed during this call, including any carried-forward amount.
	//   - bool: false only when emission is halted; true when processing completes, including a no-op call.
	MintAndDistributeGns(_ int, rlm realm) (int64, bool)

	// GetStakerEmissionAmountPerSecond returns the current GNS emission rate allocated to liquidity stakers.
	//
	// Returns:
	//   - int64: Current staker allocation in GNS units per second.
	//   - error: Non-nil when the emission distribution configuration cannot provide a staker rate; nil otherwise.
	GetStakerEmissionAmountPerSecond() (int64, error)

	// GetStakerEmissionAmountPerSecondInRange returns staker emission-rate change points over an inclusive time range.
	//
	// Parameters:
	//   - start: Inclusive lower bound as a Unix timestamp.
	//   - end: Inclusive upper bound as a Unix timestamp.
	//
	// Returns:
	//   - []int64: Unix timestamps at which the underlying GNS emission rate changes.
	//   - []int64: Staker emission amounts in GNS units per second at the corresponding timestamps.
	//   - error: Non-nil when the emission distribution configuration is invalid; nil when both slices are produced.
	GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64, error)

	// SetOnDistributionPctChangeCallback registers a callback for staker distribution-percentage changes.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before the callback is registered.
	//   - callback: Callback invoked with the internal discriminator, current emission realm, and the new staker emission amount per second.
	SetOnDistributionPctChangeCallback(_ int, rlm realm, callback func(_ int, rlm realm, emissionAmountPerSecond int64))
}

type emissionAccessor struct{}

// MintAndDistributeGns mints and distributes scheduled GNS emission through the emission realm.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before crossing into the emission realm.
//
// Returns:
//   - int64: GNS amount distributed during this call, including any carried-forward amount.
//   - bool: false only when emission is halted; true when processing completes, including a no-op call.
func (e *emissionAccessor) MintAndDistributeGns(_ int, rlm realm) (int64, bool) {
	access.AssertIsRlmCurrent(0, rlm)

	return emission.MintAndDistributeGns(cross(rlm))
}

// GetStakerEmissionAmountPerSecond returns the current GNS emission rate allocated to liquidity stakers.
//
// Returns:
//   - int64: Current staker allocation in GNS units per second.
//   - error: Non-nil when the emission distribution configuration cannot provide a staker rate; nil otherwise.
func (e *emissionAccessor) GetStakerEmissionAmountPerSecond() (int64, error) {
	return emission.GetStakerEmissionAmountPerSecond()
}

// GetStakerEmissionAmountPerSecondInRange returns staker emission-rate change points over an inclusive time range.
//
// Parameters:
//   - start: Inclusive lower bound as a Unix timestamp.
//   - end: Inclusive upper bound as a Unix timestamp.
//
// Returns:
//   - []int64: Unix timestamps at which the underlying GNS emission rate changes.
//   - []int64: Staker emission amounts in GNS units per second at the corresponding timestamps.
//   - error: Non-nil when the emission distribution configuration is invalid; nil when both slices are produced.
func (e *emissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64, error) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

// SetOnDistributionPctChangeCallback registers a callback for staker distribution-percentage changes.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before the callback is registered.
//   - callback: Callback invoked with the internal discriminator, current emission realm, and the new staker emission amount per second.
func (e *emissionAccessor) SetOnDistributionPctChangeCallback(_ int, rlm realm, callback func(_ int, rlm realm, emissionAmountPerSecond int64)) {
	access.AssertIsRlmCurrent(0, rlm)

	// Wrap the caller-provided callback in an adapter constructed HERE, inside
	// the /r/gnoswap/staker domain package. By borrow rule #3 the wrapper
	// closure is owned by /r/gnoswap/staker (its construction realm), not by the
	// v1 implementation that passed `callback` in. This mirrors the swap/tick
	// hook accessors above and lets emission persist the callback into its
	// package-level var without hitting "cannot persist realm value" (which
	// fired when a v1-constructed closure was stored there directly).
	emission.SetOnDistributionPctChangeCallback(cross(rlm), func(cur realm, emissionAmountPerSecond int64) {
		callback(0, cur, emissionAmountPerSecond)
	})
}

// newEmissionAccessor constructs the emission accessor used by staker implementations.
//
// Returns:
//   - EmissionAccessor: Accessor that forwards GNS minting and staker emission queries.
func newEmissionAccessor() EmissionAccessor {
	return &emissionAccessor{}
}

type NFTAccessor interface {
	// Approve grants an address permission to transfer a specific NFT.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
	//   - approved: Address receiving permission for tid.
	//   - tid: NFT token ID whose approval is changed.
	//
	// Returns:
	//   - error: Non-nil when the NFT realm rejects the approval or the realm context is spoofed; nil on success.
	Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error

	// Mint creates an NFT with tid and transfers it to to.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
	//   - to: Address receiving the newly minted NFT.
	//   - tid: Token ID to mint.
	//
	// Returns:
	//   - grc721.TokenID: The minted token ID, equal to tid.
	Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID

	// Burn destroys an NFT.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
	//   - tid: NFT token ID to burn.
	Burn(_ int, rlm realm, tid grc721.TokenID)

	// TransferFrom moves an NFT from its current owner to another address.
	//
	// Parameters:
	//   - _: Internal call discriminator; callers pass 0.
	//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
	//   - from: Current owner address of tid.
	//   - to: Recipient address for tid.
	//   - tid: NFT token ID to transfer.
	//
	// Returns:
	//   - error: Non-nil when the NFT realm rejects the transfer or the realm context is spoofed; nil on success.
	TransferFrom(_ int, rlm realm, from, to address, tid grc721.TokenID) error

	// TotalSupply returns the number of NFTs currently minted and not burned.
	//
	// Returns:
	//   - int64: Current NFT collection supply.
	TotalSupply() int64

	// Exists reports whether an NFT token ID is currently minted.
	//
	// Parameters:
	//   - tid: NFT token ID to look up.
	//
	// Returns:
	//   - bool: true when tid has an owner in the NFT ledger; false when it does not exist.
	Exists(tid grc721.TokenID) bool

	// MustOwnerOf returns the owner of an NFT and panics when tid is invalid.
	//
	// Parameters:
	//   - tid: NFT token ID whose owner is required.
	//
	// Returns:
	//   - address: Current owner address of tid; the accessor panics if tid does not exist.
	MustOwnerOf(tid grc721.TokenID) address

	// OwnerOf returns the owner of an NFT without panicking on lookup failure.
	//
	// Parameters:
	//   - tid: NFT token ID whose owner is queried.
	//
	// Returns:
	//   - address: Current owner address, or the zero address when lookup fails.
	//   - error: Non-nil when tid does not exist or the NFT realm cannot resolve its owner.
	OwnerOf(tid grc721.TokenID) (address, error)
}

type gnftAccessor struct{}

// Approve grants an address permission to transfer a specific NFT.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
//   - approved: Address receiving permission for tid.
//   - tid: NFT token ID whose approval is changed.
//
// Returns:
//   - error: Non-nil when the NFT realm rejects the approval or the realm context is spoofed; nil on success.
func (n *gnftAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return gnft.Approve(cross(rlm), approved, tid)
}

// Mint creates an NFT with tid and transfers it to to.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
//   - to: Address receiving the newly minted NFT.
//   - tid: Token ID to mint.
//
// Returns:
//   - grc721.TokenID: The minted token ID, equal to tid.
func (n *gnftAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	access.AssertIsRlmCurrent(0, rlm)

	return gnft.Mint(cross(rlm), to, tid)
}

// Burn destroys an NFT.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
//   - tid: NFT token ID to burn.
func (n *gnftAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	access.AssertIsRlmCurrent(0, rlm)

	gnft.Burn(cross(rlm), tid)
}

// TransferFrom moves an NFT from its current owner to another address.
//
// Parameters:
//   - _: Internal call discriminator; callers pass 0.
//   - rlm: Propagated realm context; it must be current before crossing into the NFT realm.
//   - from: Current owner address of tid.
//   - to: Recipient address for tid.
//   - tid: NFT token ID to transfer.
//
// Returns:
//   - error: Non-nil when the NFT realm rejects the transfer or the realm context is spoofed; nil on success.
func (n *gnftAccessor) TransferFrom(_ int, rlm realm, from, to address, tid grc721.TokenID) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return gnft.TransferFrom(cross(rlm), from, to, tid)
}

// TotalSupply returns the number of NFTs currently minted and not burned.
//
// Returns:
//   - int64: Current NFT collection supply.
func (n *gnftAccessor) TotalSupply() int64 {
	return gnft.TotalSupply()
}

// Exists reports whether an NFT token ID is currently minted.
//
// Parameters:
//   - tid: NFT token ID to look up.
//
// Returns:
//   - bool: true when tid has an owner in the NFT ledger; false when it does not exist.
func (n *gnftAccessor) Exists(tid grc721.TokenID) bool {
	return gnft.Exists(tid)
}

// MustOwnerOf returns the owner of an NFT and panics when tid is invalid.
//
// Parameters:
//   - tid: NFT token ID whose owner is required.
//
// Returns:
//   - address: Current owner address of tid; the accessor panics if tid does not exist.
func (n *gnftAccessor) MustOwnerOf(tid grc721.TokenID) address {
	owner, err := gnft.OwnerOf(tid)
	if err != nil {
		panic(err.Error())
	}
	return owner
}

// OwnerOf returns the owner of an NFT without panicking on lookup failure.
//
// Parameters:
//   - tid: NFT token ID whose owner is queried.
//
// Returns:
//   - address: Current owner address, or the zero address when lookup fails.
//   - error: Non-nil when tid does not exist or the NFT realm cannot resolve its owner.
func (n *gnftAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	return gnft.OwnerOf(tid)
}

// newNFTAccessor constructs the NFT accessor used by staker implementations.
//
// Returns:
//   - NFTAccessor: Accessor that forwards NFT ownership and transfer operations.
func newNFTAccessor() NFTAccessor {
	return &gnftAccessor{}
}
