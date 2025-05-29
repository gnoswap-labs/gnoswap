package position

import (
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

var (
	positions = avl.NewTree() // positionId[uint64] -> Position
	nextId    = int64(1)
)

// GetPosition returns a position for a given position ID.
// Returns false if position doesn't exist
func GetPosition(id int64) (Position, bool) {
	idStr := strconv.FormatInt(id, 10)
	iPosition, exist := positions.Get(idStr)
	if !exist {
		return Position{}, false
	}

	return iPosition.(Position), true
}

// MustGetPosition returns a position for a given position ID.
// panics if position doesn't exist
func MustGetPosition(id int64) Position {
	position, exist := GetPosition(id)
	if !exist {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", id),
		))
	}
	return position
}

// ExistPosition checks if a position exists for a given position ID
func ExistPosition(id int64) bool {
	_, exist := GetPosition(id)
	return exist
}

// GetNextId is the next position ID to be minted
func GetNextId() int64 {
	return nextId
}

// createNewPosition creates a new position with the given position data.
func createNewPosition(id int64, pos Position) int64 {
	if ExistPosition(id) {
		panic(newErrorWithDetail(
			errPositionExist,
			ufmt.Sprintf("positionId(%d)", id),
		))
	}
	setPosition(id, pos)
	incrementNextId()
	return id
}

// setPosition sets a position for a given position ID.
// Returns true if position is newly created, false if position already exists and just updated.
func setPosition(id int64, position Position) bool {
	posIdStr := strconv.FormatInt(id, 10)
	return positions.Set(posIdStr, position)
}

// mustUpdatePosition updates a position for a given position ID.
func mustUpdatePosition(id int64, pos Position) {
	update := setPosition(id, pos)
	if !update {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", id),
		))
	}
}

// removePosition removes a position for a given position ID
func removePosition(id int64) {
	posIdStr := strconv.FormatInt(id, 10)
	positions.Remove(posIdStr)
}

// incrementNextId increments the next position ID to be minted
func incrementNextId() {
	nextId++
}
