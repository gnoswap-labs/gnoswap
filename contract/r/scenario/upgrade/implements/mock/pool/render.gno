package mock

func (t *TestPool) Render(path string) string {
	return t.instance.Render(path)
}
