package router

// Render delegates web rendering to the active implementation.
func Render(path string) string {
	return getImplementation().Render(path)
}
