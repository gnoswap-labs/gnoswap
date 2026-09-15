package mock

func (t *TestRouter) Render(path string) string {
	return t.instance.Render(path)
}
