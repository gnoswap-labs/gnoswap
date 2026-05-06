package runtime_frame

import (
	"chain"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
)

func TestDirectMsgCallUserFrame(t *testing.T) {
	userAddr := testutils.TestAddress("runtime-frame-user")
	testing.SetRealm(testing.NewUserRealm(userAddr))

	assertFrameSnapshot(t, "direct MsgCall user", CurrentFrameSnapshot(), FrameSnapshot{
		Address: userAddr.String(),
		PkgPath: "",
		IsUser:  true,
		IsCode:  false,
	})
}

func TestDeployedRealmFrame(t *testing.T) {
	const pkgPath = "gno.land/r/gnoswap/scenario/patterns/runtime_frame"
	testing.SetRealm(testing.NewCodeRealm(pkgPath))

	assertFrameSnapshot(t, "deployed /r realm", CurrentFrameSnapshot(), FrameSnapshot{
		Address: chain.PackageAddress(pkgPath).String(),
		PkgPath: pkgPath,
		IsUser:  false,
		IsCode:  true,
	})
}

func assertFrameSnapshot(t *testing.T, name string, got FrameSnapshot, want FrameSnapshot) {
	if got.Address != want.Address {
		t.Errorf("%s Address() = %s, want %s", name, got.Address, want.Address)
	}
	if got.PkgPath != want.PkgPath {
		t.Errorf("%s PkgPath() = %s, want %s", name, got.PkgPath, want.PkgPath)
	}
	if got.IsUser != want.IsUser {
		t.Errorf("%s IsUser() = %v, want %v", name, got.IsUser, want.IsUser)
	}
	if got.IsCode != want.IsCode {
		t.Errorf("%s IsCode() = %v, want %v", name, got.IsCode, want.IsCode)
	}
}
