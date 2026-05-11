package v1

func (i *poolV1) lockPool() {
	if i.store.HasUnlocked() && !i.store.GetUnlocked() {
		panic(errLockedPool)
	}

	if err := i.store.SetUnlocked(false); err != nil {
		panic(err)
	}
}

func (i *poolV1) unlockPool() {
	if err := i.store.SetUnlocked(true); err != nil {
		panic(err)
	}
}
