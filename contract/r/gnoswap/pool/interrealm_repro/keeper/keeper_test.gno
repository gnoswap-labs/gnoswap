package keeper

import (
	"testing"

	"gno.land/p/nt/uassert/v0"
)

// The slot-overwrite of a key whose value is owned by another realm aborts with
// the readonly-tainted-object panic crossing the realm boundary.
func TestUpdateForeignValue_Aborts(cur realm, t *testing.T) {
	uassert.AbortsContains(t, cur, "readonly tainted object", func() {
		UpdateForeignValue(cross(cur))
	})
}

// The exact same insert-then-update, but with a value owned by this realm,
// does not panic — isolating the held-value ownership as the sole difference.
func TestUpdateOwnValue_OK(cur realm, t *testing.T) {
	uassert.NotPanics(t, cur, func() {
		UpdateOwnValue(cross(cur))
	})

	v, ok := ownTree.Get("k")
	if !ok {
		t.Fatal("key k missing after update")
	}
	if got := v.(*Local).N; got != 2 {
		t.Fatalf("got N=%d, want 2", got)
	}
}
