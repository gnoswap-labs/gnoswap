// Package keeper owns a persisted /p/ bptree and demonstrates the interrealm v2
// "readonly tainted object" panic on the /p/-container slot-overwrite path —
// the follow-up to https://github.com/gnolang/gno/issues/5736 that PR #5747
// does not touch.
//
// This is the same class of bug that forced pool/v1 to drop its savePool ->
// pools.Set call (see docs/interrealm-v2/). The key observation is that the
// panic does NOT depend on crossing, nor on the "update an existing key" branch
// by itself. It depends solely on the home realm of the value the slot
// currently holds:
//
//   - UpdateForeignValue: the slot holds a value owned by ANOTHER realm
//     (box.Box) -> the second Set (update branch) panics.
//   - UpdateOwnValue: the slot holds a value owned by THIS realm
//     -> the second Set updates fine.
//
// Both run in the same realm context and both take the update branch; only the
// ownership of the held value differs.
package keeper

import (
	"gno.land/p/nt/bptree/v0"
	"gno.land/r/gnoswap/pool/interrealm_repro/box"
)

// foreignTree and ownTree are owned by this realm (persisted in realm storage).
var (
	foreignTree = bptree.NewBPTreeN(32)
	ownTree     = bptree.NewBPTreeN(32)
)

// Local is a value type owned by THIS realm.
type Local struct {
	N int
}

// UpdateForeignValue stores a value owned by the box realm and then overwrites
// the same key. The second Set hits `*leaf.values[pos] = value` whose held
// value's home realm is the box realm, tripping IsReadonlyBy's inner recursion.
// Mirrors gnoswap pool/v1 savePool -> pools.Set(*Pool owned by /r/.../pool).
func UpdateForeignValue(cur realm) {
	foreignTree.Set("k", box.Make(1)) // insert: OK
	foreignTree.Set("k", box.Make(2)) // update same key: PANIC
}

// UpdateOwnValue does the exact same insert-then-update, but with a value owned
// by this realm. Same update branch, same realm context -> no panic. Mirrors
// gnoswap pool/v1 setTick -> p.ticks.Set(TickInfo owned by the same realm as
// the tree), which is why that path never tainted.
func UpdateOwnValue(cur realm) {
	ownTree.Set("k", &Local{N: 1}) // insert: OK
	ownTree.Set("k", &Local{N: 2}) // update same key: OK
}
