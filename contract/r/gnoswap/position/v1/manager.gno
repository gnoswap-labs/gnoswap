package v1

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/position"
)

// GetNextId is the next position ID to be minted
func (p *positionV1) getNextId() uint64 {
	return p.store.GetPositionNextID()
}

// incrementNextId increments the next position ID to be minted
func (p *positionV1) incrementNextId() error {
	nextId := p.getNextId()

	return p.store.SetPositionNextID(nextId + 1)
}

// createNewPosition creates a new position with the given position data.
func (p *positionV1) createNewPosition(id uint64, pos position.Position) uint64 {
	if p.ExistPosition(id) {
		panic(newErrorWithDetail(
			errPositionExist,
			ufmt.Sprintf("positionId(%d)", id),
		))
	}

	err := p.setPosition(id, pos)
	if err != nil {
		panic(err)
	}

	err = p.incrementNextId()
	if err != nil {
		panic(err)
	}

	return id
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

// removePosition removes a position for a given position ID
func (p *positionV1) removePosition(id uint64) {
	err := p.store.RemovePosition(id)
	if err != nil {
		panic(err)
	}
}
