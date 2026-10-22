package dca_order

import (
	dca "gno.land/r/gnoswap/test/dca_order"
)

func init(cur realm) {
	registerDCAOrderV1(cur)
}

func registerDCAOrderV1(cur realm) {
	dca.RegisterInitializer(cross(cur), func(_ int, rlm realm, dcaStore dca.IDCAOrderStore) dca.IDCAOrder {
		err := initStoreData(0, rlm, dcaStore)
		if err != nil {
			panic(err)
		}

		return NewDCAOrderV1(dcaStore)
	})
}

func initStoreData(_ int, rlm realm, s dca.IDCAOrderStore) error {
	if !s.HasOrders() {
		if err := s.SetOrders(0, rlm, dca.NewBPTreeN(bptreeFanout)); err != nil {
			return err
		}
	}

	if !s.HasOrdersByOwner() {
		if err := s.SetOrdersByOwner(0, rlm, dca.NewBPTreeN(bptreeFanout)); err != nil {
			return err
		}
	}

	if !s.HasGroups() {
		if err := s.SetGroups(0, rlm, dca.NewBPTreeN(bptreeFanout)); err != nil {
			return err
		}
	}

	if !s.HasScheduledGroups() {
		if err := s.SetScheduledGroups(0, rlm, dca.NewBPTreeN(bptreeFanout)); err != nil {
			return err
		}
	}

	if !s.HasPendingFees() {
		if err := s.SetPendingFees(0, rlm, dca.NewBPTreeN(bptreeFanout)); err != nil {
			return err
		}
	}

	if !s.HasNextOrderID() {
		if err := s.SetNextOrderID(0, rlm, 1); err != nil {
			return err
		}
	}

	if !s.HasConfig() {
		config := dca.NewConfig(defaultCreationFeeBps, defaultMinAmountPerExecution, defaultMaxTotalExecutions)
		if err := s.SetConfig(0, rlm, config); err != nil {
			return err
		}
	}

	return nil
}
