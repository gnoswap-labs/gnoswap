package mock

func (t *TestGovStaker) Render(path string) string {
	return t.instance.Render(path)
}
