package launchpad

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStoreSetAndGetProjects(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		uassert.False(t, ls.HasProjectsKey(), "should not have projects initially")

		projects := avl.NewTree()
		err := ls.SetProjects(projects)
		uassert.NoError(t, err)

		uassert.True(t, ls.HasProjectsKey(), "should have projects after setting")

		retrieved := ls.GetProjects()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized projects")
		}()

		ls.GetProjects()
	})
}

func TestStoreSetAndGetProjectTierRewardManagers(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		uassert.False(t, ls.HasProjectTierRewardManagersKey(), "should not have project tier reward managers initially")

		managers := avl.NewTree()
		err := ls.SetProjectTierRewardManagers(managers)
		uassert.NoError(t, err)

		uassert.True(t, ls.HasProjectTierRewardManagersKey(), "should have project tier reward managers after setting")

		retrieved := ls.GetProjectTierRewardManagers()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized project tier reward managers")
		}()

		ls.GetProjectTierRewardManagers()
	})
}

func TestStoreSetAndGetDepositCounter(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		uassert.False(t, ls.HasDepositCounterStoreKey(), "should not have deposit counter initially")

		counter := &Counter{}
		err := ls.SetDepositCounter(counter)
		uassert.NoError(t, err)

		uassert.True(t, ls.HasDepositCounterStoreKey(), "should have deposit counter after setting")

		retrieved := ls.GetDepositCounter()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized deposit counter")
		}()

		ls.GetDepositCounter()
	})
}

func TestStoreNextDepositID(t *testing.T) {
	resetTestState(t)

	ls := NewLaunchpadStore(kvStore)

	counter := &Counter{}
	err := ls.SetDepositCounter(counter)
	uassert.NoError(t, err)

	id1 := ls.NextDepositID()
	uassert.Equal(t, "1", id1)

	id2 := ls.NextDepositID()
	uassert.Equal(t, "2", id2)

	id3 := ls.NextDepositID()
	uassert.Equal(t, "3", id3)
}

func TestStoreSetAndGetDeposits(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		uassert.False(t, ls.HasDepositsKey(), "should not have deposits initially")

		deposits := avl.NewTree()
		err := ls.SetDeposits(deposits)
		uassert.NoError(t, err)

		uassert.True(t, ls.HasDepositsKey(), "should have deposits after setting")

		retrieved := ls.GetDeposits()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ls := NewLaunchpadStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized deposits")
		}()

		ls.GetDeposits()
	})
}

func TestStoreMultipleSetAndGet(t *testing.T) {
	resetTestState(t)

	ls := NewLaunchpadStore(kvStore)

	projects := avl.NewTree()
	projects.Set("project1", "data1")
	err := ls.SetProjects(projects)
	uassert.NoError(t, err)

	managers := avl.NewTree()
	managers.Set("manager1", "mdata1")
	err = ls.SetProjectTierRewardManagers(managers)
	uassert.NoError(t, err)

	counter := &Counter{}
	err = ls.SetDepositCounter(counter)
	uassert.NoError(t, err)

	deposits := avl.NewTree()
	deposits.Set("deposit1", "ddata1")
	err = ls.SetDeposits(deposits)
	uassert.NoError(t, err)

	uassert.True(t, ls.HasProjectsKey())
	uassert.True(t, ls.HasProjectTierRewardManagersKey())
	uassert.True(t, ls.HasDepositCounterStoreKey())
	uassert.True(t, ls.HasDepositsKey())

	retrievedProjects := ls.GetProjects()
	val, _ := retrievedProjects.Get("project1")
	uassert.Equal(t, "data1", val)

	retrievedManagers := ls.GetProjectTierRewardManagers()
	val, _ = retrievedManagers.Get("manager1")
	uassert.Equal(t, "mdata1", val)

	retrievedCounter := ls.GetDepositCounter()
	uassert.NotEqual(t, nil, retrievedCounter)

	retrievedDeposits := ls.GetDeposits()
	val, _ = retrievedDeposits.Get("deposit1")
	uassert.Equal(t, "ddata1", val)
}

