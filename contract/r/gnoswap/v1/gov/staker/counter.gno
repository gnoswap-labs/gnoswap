package staker

type Counter struct {
	id int64
}

func NewCounter() *Counter {
	return &Counter{
		id: 0,
	}
}

func (c *Counter) next() int64 {
	c.id++

	return c.id
}

func (c *Counter) Get() int64 {
	return c.id
}
