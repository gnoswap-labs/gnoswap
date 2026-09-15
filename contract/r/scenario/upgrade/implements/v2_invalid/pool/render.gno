package v2_invalid

func (t *TestPool) Render(path string) string {
	return t.instance.Render(path)
}
