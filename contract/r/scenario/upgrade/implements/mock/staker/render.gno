package mock

func (t *TestStaker) Render(path string) string {
	return t.instance.Render(path)
}
