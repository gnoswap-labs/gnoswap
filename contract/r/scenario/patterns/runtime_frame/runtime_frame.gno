package runtime_frame

import "chain/runtime"

type FrameSnapshot struct {
	Address string
	PkgPath string
	IsUser  bool
	IsCode  bool
}

func CurrentFrameSnapshot() FrameSnapshot {
	current := runtime.CurrentRealm()
	return FrameSnapshot{
		Address: current.Address().String(),
		PkgPath: current.PkgPath(),
		IsUser:  current.IsUser(),
		IsCode:  current.IsCode(),
	}
}
