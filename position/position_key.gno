package position

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
)

func positionKeyCompute(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}
