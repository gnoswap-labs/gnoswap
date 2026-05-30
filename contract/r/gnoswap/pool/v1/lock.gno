package v1

// assertPoolUnlocked is the read-only reentrancy guard. It reports the global
// pool lock state without mutating it, so it is safe to call before the access
// checks: a call that aborts on authorization afterwards leaves no persisted
// lock behind (which would otherwise leak under interrealm v2, where a panic
// crossing the realm boundary skips the deferred unlockPool). It also keeps the
// "cannot modify pool while locked" message as the first failure for any
// entrypoint invoked while a swap holds the lock (reentrancy protection).
func (i *poolV1) assertPoolUnlocked() {
	if i.store.HasUnlocked() && !i.store.GetUnlocked() {
		panic(errLockedPool)
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
