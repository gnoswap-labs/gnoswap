package position

import (
	"std"
	"testing"
	nft "gno.land/r/foo721"
	"gno.land/p/demo/grc/grc721"
	
)

func TestApiGetPoolList(t *testing.T) {
	tapl := ApiGetPoolList()
	println(tapl)
}

func TestApiGetPositionList(t *testing.T) {
	tapi := ApiGetPositionList()
	println(tapi)
}