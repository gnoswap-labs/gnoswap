package bridge

type EmissionCallbacks struct {
	MintAndDistributeGns func() uint64
}

var emissionCallbacks EmissionCallbacks

func RegisterEmissionCallbacks(cb EmissionCallbacks) {
	emissionCallbacks = cb
}

func GetEmissionCallbacks() EmissionCallbacks {
	return emissionCallbacks
}

func MintAndDistributeGnsCallback() uint64 {
    if emissionCallbacks.MintAndDistributeGns == nil {
        panic("MintAndDistributeGns callback is not set!")
    }
    return emissionCallbacks.MintAndDistributeGns()
}
