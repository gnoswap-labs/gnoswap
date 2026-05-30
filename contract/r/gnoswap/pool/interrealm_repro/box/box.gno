// Package box owns the value type that gets stored into another realm's /p/
// container, used to reproduce the interrealm v2 "/p/-container slot-overwrite"
// readonly taint — the follow-up to https://github.com/gnolang/gno/issues/5736
// that PR #5747 does not touch.
//
// See the sibling keeper package and docs/interrealm-v2/ for context.
package box

type Box struct {
	N int
}

// Make returns a *Box allocated (and therefore owned) by this realm.
func Make(n int) *Box {
	return &Box{N: n}
}
