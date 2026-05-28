package v1

func (i *poolV1) lockPool(_ int, rlm realm) {
	if i.store.HasUnlocked() && !i.store.GetUnlocked() {
		panic(errLockedPool)
	}

	if err := i.store.SetUnlocked(0, rlm, false); err != nil {
		panic(err)
	}
}

func (i *poolV1) unlockPool(_ int, rlm realm) {
	if err := i.store.SetUnlocked(0, rlm, true); err != nil {
		panic(err)
	}
}
