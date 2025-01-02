package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

func TestDepositStore(t *testing.T) {
	setupTestProject := func() (*DepositStore, *Project, std.Address) {
		ds := &DepositStore{
			deposits:            avl.NewTree(),
			depositsByProject:   avl.NewTree(),
			depositsByUser:      avl.NewTree(),
			depositsByUserProject: avl.NewTree(),
		}

		testAddr := testutils.TestAddress("test")

		project := &Project{
			id:            "test:1",
			name:          "Test Project",
			tokenPath:     "test/token",
			depositAmount: 1000000,
			recipient:     testAddr,
			startHeight:   90,
			endHeight:     10000,
			tier30: Tier{
				id:                  "test:1:30",
				collectWaitDuration: 100,
				tierAmount:         300000,
				startHeight:        100,
				endHeight:         3100,
				actualDepositAmount: 0,
			},
			tier90: Tier{
				id:                  "test:1:90",
				collectWaitDuration: 200,
				tierAmount:         300000,
				startHeight:        100,
				endHeight:         6100,
				actualDepositAmount: 0,
			},
			tier180: Tier{
				id:                  "test:1:180",
				collectWaitDuration: 300,
				tierAmount:         400000,
				startHeight:        100,
				endHeight:         9100,
				actualDepositAmount: 0,
			},
		}

		projects[project.id] = *project

		return ds, project, testAddr
	}

	t.Run("AddDeposit - Pass", func(t *testing.T) {
		ds, project, testAddr := setupTestProject()

		depositId, err := ds.AddDeposit(project.id, testAddr, 1000, "30")
		uassert.NoError(t, err)

		deposit, err := ds.GetDeposit(depositId)
		uassert.NoError(t, err)

		uassert.Equal(t, deposit.amount, uint64(1000))
		uassert.Equal(t, deposit.tier, "30")
		uassert.Equal(t, deposit.depositor, testAddr)
	})

	t.Run("AddDeposit - Fail - Not Found Project", func(t *testing.T) {
		ds, _, testAddr := setupTestProject()

		_, err := ds.AddDeposit("invalid:1", testAddr, 1000, "30")
		uassert.Error(t, err)
	})

	t.Run("GetUserDeposits - Check user deposits", func(t *testing.T) {
		ds, project, testAddr := setupTestProject()

		_, err1 := ds.AddDeposit(project.id, testAddr, 1000, "30")
		_, err2 := ds.AddDeposit(project.id, testAddr, 2000, "90")
		uassert.NoError(t, err1)
		uassert.NoError(t, err2)

		deposits, err := ds.GetUserDeposits(testAddr)
		uassert.NoError(t, err)

		uassert.Equal(t, len(deposits), 2)

		totalAmount := uint64(0)
		for _, d := range deposits {
			totalAmount += d.amount
		}

		uassert.Equal(t, totalAmount, uint64(3000))
	})

	t.Run("CollectDeposit - Fail - Unauthorized", func(t *testing.T) {
		ds, project, testAddr := setupTestProject()
		unauthorizedAddr := testutils.TestAddress("unauthorized")

		depositId, _ := ds.AddDeposit(project.id, testAddr, 1000, "30")

		_, err := ds.CollectDeposit(depositId, unauthorizedAddr)
		uassert.Error(t, err)
	})

	t.Run("Check Index Consistency", func(t *testing.T) {
		ds, project, testAddr := setupTestProject()
		depositId, _ := ds.AddDeposit(project.id, testAddr, 1000, "30")

		projectKey := project.id + ":30"
		value, exists := ds.depositsByProject.Get(projectKey)
		uassert.True(t, exists)

		depositIds := value.([]string)
		uassert.Equal(t, len(depositIds), 1)
		uassert.Equal(t, depositIds[0], depositId)

		value, exists = ds.depositsByUser.Get(testAddr.String())
		uassert.True(t, exists)

		depositIds = value.([]string)
		uassert.Equal(t, len(depositIds), 1)
		uassert.Equal(t, depositIds[0], depositId)

		userProjectKey := testAddr.String() + ":" + project.id
		value, exists = ds.depositsByUserProject.Get(userProjectKey)
		uassert.True(t, exists)

		depositIds = value.([]string)
		uassert.Equal(t, len(depositIds), 1)
		uassert.Equal(t, depositIds[0], depositId)
	})
}
