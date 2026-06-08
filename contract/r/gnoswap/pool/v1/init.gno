package v1

import (
	"gno.land/r/gnoswap/pool"
)

const (
	// slot0FeeProtocol represents the protocol fee percentage (0-10).
	// This parameter can be modified through governance.
	defaultSlot0FeeProtocol = uint8(0)

	// poolCreationFee is the fee that is charged when a user creates a pool.
	// The fee is denominated in GNS tokens.
	// This parameter can be modified through governance.
	defaultPoolCreationFee = int64(100_000_000) // 100_GNS

	// withdrawalFeeBPS is the fee that is charged when a user withdraws their collected fees
	// The fee is denominated in BPS (Basis Points)
	// Example: 100 BPS = 1%
	// This parameter can be modified through governance.
	defaultWithdrawalFeeBPS = uint64(100)

	defaultUnlocked = true
)

func init(cur realm) {
	registerPoolV1(cur)
}

func registerPoolV1(cur realm) {
	pool.RegisterInitializer(cross(cur), func(_ int, rlm realm, poolStore pool.IPoolStore) pool.IPool {
		if !rlm.IsCurrent() {
			panic(errSpoofedRealm)
		}

		err := initStoreData(0, rlm, poolStore)
		if err != nil {
			panic(err)
		}

		return NewPoolV1(poolStore)
	})
}

func initStoreData(_ int, rlm realm, poolStore pool.IPoolStore) error {
	if !poolStore.HasPools() {
		err := poolStore.SetPools(0, rlm, pool.NewPoolsTree())
		if err != nil {
			return err
		}
	}

	if !poolStore.HasFeeAmountTickSpacing() {
		err := poolStore.SetFeeAmountTickSpacing(0, rlm, pool.NewDefaultFeeAmountTickSpacing())
		if err != nil {
			return err
		}
	}

	if !poolStore.HasPoolCreationFee() {
		err := poolStore.SetPoolCreationFee(0, rlm, defaultPoolCreationFee)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasPendingProtocolFees() {
		err := poolStore.SetPendingProtocolFees(0, rlm, make(map[string]int64))
		if err != nil {
			return err
		}
	}

	if !poolStore.HasSlot0FeeProtocol() {
		err := poolStore.SetSlot0FeeProtocol(0, rlm, defaultSlot0FeeProtocol)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasWithdrawalFeeBPS() {
		err := poolStore.SetWithdrawalFeeBPS(0, rlm, defaultWithdrawalFeeBPS)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasUnlocked() {
		err := poolStore.SetUnlocked(0, rlm, defaultUnlocked)
		if err != nil {
			return err
		}
	}

	// Initialize swap start hook with no-op function
	if !poolStore.HasSwapStartHook() {
		noopSwapStart := func(cur realm, poolPath string, timestamp int64) {}
		err := poolStore.SetSwapStartHook(0, rlm, noopSwapStart)
		if err != nil {
			return err
		}
	}

	// Initialize swap end hook with no-op function
	if !poolStore.HasSwapEndHook() {
		noopSwapEnd := func(cur realm, poolPath string) error {
			return nil
		}
		err := poolStore.SetSwapEndHook(0, rlm, noopSwapEnd)
		if err != nil {
			return err
		}
	}

	// Initialize tick cross hook with no-op function
	if !poolStore.HasTickCrossHook() {
		noopTickCross := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {}
		err := poolStore.SetTickCrossHook(0, rlm, noopTickCross)
		if err != nil {
			return err
		}
	}

	return nil
}
