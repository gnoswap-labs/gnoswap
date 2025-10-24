package v1

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
	defaultWithdrawalFeeBPS = uint64(1000)
)

func init() {
	registerPoolV1()
}

func registerPoolV1() {
	pool.RegisterInitializer(cross, func(poolStore pool.IPoolStore) pool.IPool {
		err := initStoreData(poolStore)
		if err != nil {
			return nil
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
		tickSpacingTree := avl.NewTree()
		tickSpacingTree.Set("100", int32(1))
		tickSpacingTree.Set("500", int32(10))
		tickSpacingTree.Set("3000", int32(60))
		tickSpacingTree.Set("10000", int32(200))

		err := poolStore.SetFeeAmountTickSpacing(tickSpacingTree)
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

	return nil
}
