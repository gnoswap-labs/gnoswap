package gnft

import (
	"math/rand"
	"testing"
	"time"
)

func Test_genImageURI(t *testing.T) {
	// rand instance
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	imageURI := genImageURI(r)
	println(imageURI)
}
