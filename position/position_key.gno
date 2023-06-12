package position

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"std"

	"gno.land/p/demo/ufmt"
)

func PositionKeyCompute(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)
	// sum256 := sha256.Sum256([]byte(key))[:]
	// return hex.EncodeToString(sum256)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
