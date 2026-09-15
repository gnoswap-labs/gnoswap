package insecure_staker_callback

func (t *TestStaker) Render(path string) string {
	return t.instance.Render(path)
}
