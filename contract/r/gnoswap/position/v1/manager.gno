package v1

import (
	"gno.land/r/gnoswap/position"
)

// GetNextId is the next position ID to be minted
func (p *positionV1) getNextId() uint64 {
	return p.store.GetPositionNextID()
}

// incrementNextId increments the next position ID to be minted
func (p *positionV1) incrementNextId() error {
	return p.store.SetPositionNextID(p.getNextId() + 1)
}

// setPosition sets a position for a given position ID.
// Returns false if position is newly created, true if position already existed and was updated.
func (p *positionV1) setPosition(id uint64, pos position.Position) error {
	return p.store.SetPosition(id, pos)
}

// mustUpdatePosition updates a position for a given position ID.
func (p *positionV1) mustUpdatePosition(id uint64, pos position.Position) {
	err := p.setPosition(id, pos)
	if err != nil {
		panic(err)
	}
}
