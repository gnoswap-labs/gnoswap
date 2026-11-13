package pool

import "errors"

// assertPoolUnlocked is the read-only reentrancy guard. It checks the global
// pool lock without mutating it and preserves "cannot modify pool while locked"
// as the first failure for reentrant calls. If a cross-realm callback aborts
// before the deferred unlock runs, transaction rollback discards the in-flight
// lock update.
func (i *poolV1) assertPoolUnlocked() {
	if i.store.HasUnlocked() && !i.store.GetUnlocked() {
		panic(errors.New(errLockedPool))
	}
}

func (i *poolV1) lockPool(_ int, rlm realm) {
	i.assertPoolUnlocked()

	if err := i.store.SetUnlocked(0, rlm, false); err != nil {
		panic(err)
	}
}

func (i *poolV1) unlockPool(_ int, rlm realm) {
	if err := i.store.SetUnlocked(0, rlm, true); err != nil {
		panic(err)
	}
}
