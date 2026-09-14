package pool

const ErrSpoofedRealm = "rlm does not match the current crossing frame"

// errUpgradeWhileLocked is returned when UpgradeImpl is invoked while the
// pool's reentrancy lock (StoreKeyUnlocked) is held.
const errUpgradeWhileLocked = "cannot upgrade pool implementation while pool is locked"
