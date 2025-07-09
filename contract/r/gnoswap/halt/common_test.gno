package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestBaseInfo(t *testing.T) {
	t.Run("newBaseInfo creates valid baseInfo", func(t *testing.T) {
		name := "test-name"
		desc := "test description"

		info := newBaseInfo(name, desc)

		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})

	t.Run("baseInfo with empty values", func(t *testing.T) {
		info := newBaseInfo("", "")

		uassert.Equal(t, "", info.Name())
		uassert.Equal(t, "", info.Desc())
	})

	t.Run("baseInfo with unicode characters", func(t *testing.T) {
		name := "测试名称"
		desc := "これは説明です"

		info := newBaseInfo(name, desc)

		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})

	t.Run("baseInfo with special characters", func(t *testing.T) {
		name := "test@name#123"
		desc := "test & description with <special> chars"

		info := newBaseInfo(name, desc)

		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})
}

func TestBaseInfoInterface(t *testing.T) {
	t.Run("baseInfo implements baseOp interface", func(t *testing.T) {
		var op baseOp = newBaseInfo("test", "description")

		uassert.Equal(t, "test", op.Name())
		uassert.Equal(t, "description", op.Desc())
	})

	t.Run("baseInfo can be used as embedded struct", func(t *testing.T) {
		// Create a custom type that embeds baseInfo
		type customType struct {
			baseInfo
			value int
		}

		custom := customType{
			baseInfo: newBaseInfo("custom", "custom desc"),
			value:    42,
		}

		uassert.Equal(t, "custom", custom.Name())
		uassert.Equal(t, "custom desc", custom.Desc())
		uassert.Equal(t, 42, custom.value)
	})
}

func TestBaseInfoModification(t *testing.T) {
	t.Run("baseInfo fields are immutable after creation", func(t *testing.T) {
		info := newBaseInfo("original", "original desc")

		// Cannot modify internal fields directly since they're private
		// This test ensures the design maintains immutability
		uassert.Equal(t, "original", info.Name())
		uassert.Equal(t, "original desc", info.Desc())
	})

	t.Run("creating multiple baseInfo instances", func(t *testing.T) {
		info1 := newBaseInfo("first", "first desc")
		info2 := newBaseInfo("second", "second desc")

		// Each instance should be independent
		uassert.Equal(t, "first", info1.Name())
		uassert.Equal(t, "first desc", info1.Desc())
		uassert.Equal(t, "second", info2.Name())
		uassert.Equal(t, "second desc", info2.Desc())
	})
}

func TestBaseInfoLongValues(t *testing.T) {
	t.Run("baseInfo with very long strings", func(t *testing.T) {
		longName := "this_is_a_very_long_name_that_should_still_work_properly_even_with_many_characters_and_underscores_and_numbers_123456789"
		longDesc := "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required."

		info := newBaseInfo(longName, longDesc)

		uassert.Equal(t, longName, info.Name())
		uassert.Equal(t, longDesc, info.Desc())
	})
}

func TestBaseInfoEdgeCases(t *testing.T) {
	t.Run("baseInfo with whitespace", func(t *testing.T) {
		name := "  name with spaces  "
		desc := "\tdescription\nwith\ttabs\nand\nnewlines  "

		info := newBaseInfo(name, desc)

		// Should preserve whitespace as-is
		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})

	t.Run("baseInfo with numeric strings", func(t *testing.T) {
		name := "12345"
		desc := "999.999"

		info := newBaseInfo(name, desc)

		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})

	t.Run("baseInfo with single characters", func(t *testing.T) {
		name := "a"
		desc := "1"

		info := newBaseInfo(name, desc)

		uassert.Equal(t, name, info.Name())
		uassert.Equal(t, desc, info.Desc())
	})
}
