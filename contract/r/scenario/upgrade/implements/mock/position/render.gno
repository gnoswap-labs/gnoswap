package mock

func (t *TestPosition) Render(path string) string {
	return t.instance.Render(path)
}
