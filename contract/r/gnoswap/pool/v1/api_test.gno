package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestMakeStatNode(t *testing.T) {
	t.Run("default block height and timestamp", func(t *testing.T) {
		statNode := newStatNode().JSON()

		statHeight, _ := statNode.GetKey("height")
		uassert.Equal(t, statHeight.String(), "123")

		statTimestamp, _ := statNode.GetKey("timestamp")
		uassert.Equal(t, statTimestamp.String(), "1234567890")
	})

	t.Run("increase block height and timestamp", func(t *testing.T) {
		testing.SkipHeights(1)

		statNode := newStatNode().JSON()

		statHeight, _ := statNode.GetKey("height")
		uassert.Equal(t, statHeight.String(), "124")
	})
}
