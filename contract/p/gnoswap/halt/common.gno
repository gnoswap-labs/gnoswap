package halt

// baseInfo contains common fields for named entities.
type baseInfo struct {
	name string
	desc string
}

func (b baseInfo) Name() string { return b.name }
func (b baseInfo) Desc() string { return b.desc }

func newBaseInfo(name, desc string) baseInfo {
	return baseInfo{name, desc}
}
