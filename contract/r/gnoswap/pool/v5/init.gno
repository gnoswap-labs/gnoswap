package v5

import (
	"gno.land/p/nt/avl"
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
)

var defaultFeeAmountTickSpacing = map[uint32]int32{
	100:   1,
	500:   10,
	3000:  60,
	10000: 200,
}

func init() {
	registerPoolV1()
}

func registerPoolV1() {
	pool.RegisterInitializer(cross, func(poolStore pool.IPoolStore) pool.IPool {
		err := initStoreData(poolStore)
		if err != nil {
			panic(err)
		}

		return NewPoolV1(poolStore)
	})
}

func initStoreData(poolStore pool.IPoolStore) error {
	if !poolStore.HasPools() {
		err := poolStore.SetPools(avl.NewTree())
		if err != nil {
			return err
		}
	}

	if !poolStore.HasFeeAmountTickSpacing() {
		err := poolStore.SetFeeAmountTickSpacing(defaultFeeAmountTickSpacing)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasPoolCreationFee() {
		err := poolStore.SetPoolCreationFee(defaultPoolCreationFee)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasSlot0FeeProtocol() {
		err := poolStore.SetSlot0FeeProtocol(defaultSlot0FeeProtocol)
		if err != nil {
			return err
		}
	}

	if !poolStore.HasWithdrawalFeeBPS() {
		err := poolStore.SetWithdrawalFeeBPS(defaultWithdrawalFeeBPS)
		if err != nil {
			return err
		}
	}

	// Initialize swap start hook with no-op function
	if !poolStore.HasSwapStartHook() {
		noopSwapStart := func(cur realm, poolPath string, timestamp int64) {}
		err := poolStore.SetSwapStartHook(noopSwapStart)
		if err != nil {
			return err
		}
	}

	// Initialize swap end hook with no-op function
	if !poolStore.HasSwapEndHook() {
		noopSwapEnd := func(cur realm, poolPath string) error {
			return nil
		}
		err := poolStore.SetSwapEndHook(noopSwapEnd)
		if err != nil {
			return err
		}
	}

	// Initialize tick cross hook with no-op function
	if !poolStore.HasTickCrossHook() {
		noopTickCross := func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {}
		err := poolStore.SetTickCrossHook(noopTickCross)
		if err != nil {
			return err
		}
	}

	return nil
}
