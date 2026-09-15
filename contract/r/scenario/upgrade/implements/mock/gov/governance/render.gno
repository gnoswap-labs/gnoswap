package mock

func (t *TestGovernance) Render(path string) string {
	return t.instance.Render(path)
}
