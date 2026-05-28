package v1

func (i *poolV1) lockPool(cur realm) {
	if i.store.HasUnlocked() && !i.store.GetUnlocked() {
		panic(errLockedPool)
	}

	if err := i.store.SetUnlocked(0, cur, false); err != nil {
		panic(err)
	}
}

func (i *poolV1) unlockPool(cur realm) {
	if err := i.store.SetUnlocked(0, cur, true); err != nil {
		panic(err)
	}
}
