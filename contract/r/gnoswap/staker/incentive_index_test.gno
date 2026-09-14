package staker

import (
	"strconv"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestIncentiveIndexRemoval(t *testing.T) {
	incentives := NewIncentives("pool")
	for n := 0; n < 40; n++ {
		incentives.AddIncentiveByStartTime(100, strconv.Itoa(n))
	}
	incentives.AddIncentiveByStartTime(200, "later")
	for n := 0; n < 40; n += 2 {
		incentives.RemoveIncentiveByStartTime(100, strconv.Itoa(n))
	}
	incentives.RemoveIncentiveByStartTime(100, "missing")
	seen := make(map[string]bool)
	incentives.IterateIncentiveIdsByTime(100, 100, func(id string) bool {
		uassert.False(t, seen[id])
		seen[id] = true
		return false
	})
	for n := 0; n < 40; n++ {
		uassert.Equal(t, n%2 == 1, seen[strconv.Itoa(n)])
	}
	for n := 1; n < 40; n += 2 {
		incentives.RemoveIncentiveByStartTime(100, strconv.Itoa(n))
	}
	incentives.RemoveIncentiveByStartTime(100, "missing")
	incentives.AddIncentiveByStartTime(100, "replacement")
	ids := []string{}
	incentives.IterateIncentiveIdsByTime(100, 200, func(id string) bool {
		ids = append(ids, id)
		return false
	})
	uassert.Equal(t, 2, len(ids))
	uassert.Equal(t, "later", ids[0])
	uassert.Equal(t, "replacement", ids[1])
}

func TestIncentiveIndexStopsAcrossBuckets(t *testing.T) {
	incentives := NewIncentives("pool")
	incentives.AddIncentiveByStartTime(99, "outside-low")
	incentives.AddIncentiveByStartTime(100, "lower-bound")
	incentives.AddIncentiveByStartTime(200, "upper-a")
	incentives.AddIncentiveByStartTime(200, "upper-b")
	incentives.AddIncentiveByStartTime(201, "outside-high")
	ids := []string{}
	incentives.IterateIncentiveIdsByTime(100, 200, func(id string) bool {
		ids = append(ids, id)
		return true
	})
	uassert.Equal(t, 1, len(ids))
	uassert.Equal(t, "upper-a", ids[0])
}
