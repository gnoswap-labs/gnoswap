package position

import (
	"gno.land/r/gnoswap/position"
)

// getNextId returns the next position NFT ID that the manager will allocate.
//
// Returns:
//   - nextID: next position ID currently stored for minting
func (p *positionV1) getNextId() uint64 {
	return p.store.GetPositionNextID()
}

// incrementNextId increments the next position ID to be minted.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context used for the storage write
//
// Returns:
//   - err: nil when the incremented ID is stored; non-nil when the realm is spoofed or the store write fails
func (p *positionV1) incrementNextId(_ int, rlm realm) error {
	return p.store.SetPositionNextID(0, rlm, p.getNextId()+1)
}

// setPosition inserts or replaces a position for a given ID.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context used for the storage write
//   - id: position NFT token ID to insert or replace
//   - pos: complete position value to persist
//
// Returns:
//   - err: nil when storage succeeds; non-nil when the realm is spoofed or the position store rejects the write
func (p *positionV1) setPosition(_ int, rlm realm, id uint64, pos position.Position) error {
	return p.store.SetPosition(0, rlm, id, pos)
}

// mustUpdatePosition stores a position for a given ID and panics if the update fails.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context used for the storage write
//   - id: position NFT token ID to update
//   - pos: complete position value to persist
func (p *positionV1) mustUpdatePosition(_ int, rlm realm, id uint64, pos position.Position) {
	err := p.setPosition(0, rlm, id, pos)
	if err != nil {
		panic(err)
	}
}
