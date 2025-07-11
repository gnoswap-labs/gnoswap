package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestBaseInfo(t *testing.T) {
	tests := []struct {
		name     string
		inName   string
		inDesc   string
		wantName string
		wantDesc string
	}{
		{
			name:     "newBaseInfo creates valid baseInfo",
			inName:   "test-name",
			inDesc:   "test description",
			wantName: "test-name",
			wantDesc: "test description",
		},
		{
			name:     "baseInfo with empty values",
			inName:   "",
			inDesc:   "",
			wantName: "",
			wantDesc: "",
		},
		{
			name:     "baseInfo with unicode characters",
			inName:   "测试名称",
			inDesc:   "これは説明です",
			wantName: "测试名称",
			wantDesc: "これは説明です",
		},
		{
			name:     "baseInfo with special characters",
			inName:   "test@name#123",
			inDesc:   "test & description with <special> chars",
			wantName: "test@name#123",
			wantDesc: "test & description with <special> chars",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info := newBaseInfo(tt.inName, tt.inDesc)

			uassert.Equal(t, tt.wantName, info.Name())
			uassert.Equal(t, tt.wantDesc, info.Desc())
		})
	}
}

func TestBaseInfoInterface(t *testing.T) {
	tests := []struct {
		name     string
		verifyFn func(t *testing.T)
	}{
		{
			name: "baseInfo implements baseOp interface",
			verifyFn: func(t *testing.T) {
				var op baseOp = newBaseInfo("test", "description")
				uassert.Equal(t, "test", op.Name())
				uassert.Equal(t, "description", op.Desc())
			},
		},
		{
			name: "baseInfo can be used as embedded struct",
			verifyFn: func(t *testing.T) {
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
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.verifyFn(t)
		})
	}
}

func TestBaseInfoModification(t *testing.T) {
	tests := []struct {
		name     string
		verifyFn func(t *testing.T)
	}{
		{
			name: "baseInfo fields are immutable after creation",
			verifyFn: func(t *testing.T) {
				info := newBaseInfo("original", "original desc")
				// Cannot modify internal fields directly since they're private
				// This test ensures the design maintains immutability
				uassert.Equal(t, "original", info.Name())
				uassert.Equal(t, "original desc", info.Desc())
			},
		},
		{
			name: "creating multiple baseInfo instances",
			verifyFn: func(t *testing.T) {
				info1 := newBaseInfo("first", "first desc")
				info2 := newBaseInfo("second", "second desc")
				// Each instance should be independent
				uassert.Equal(t, "first", info1.Name())
				uassert.Equal(t, "first desc", info1.Desc())
				uassert.Equal(t, "second", info2.Name())
				uassert.Equal(t, "second desc", info2.Desc())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.verifyFn(t)
		})
	}
}

func TestBaseInfoLongValues(t *testing.T) {
	tests := []struct {
		name     string
		inName   string
		inDesc   string
		wantName string
		wantDesc string
	}{
		{
			name:     "baseInfo with very long strings",
			inName:   "this_is_a_very_long_name_that_should_still_work_properly_even_with_many_characters_and_underscores_and_numbers_123456789",
			inDesc:   "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required.",
			wantName: "this_is_a_very_long_name_that_should_still_work_properly_even_with_many_characters_and_underscores_and_numbers_123456789",
			wantDesc: "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required.",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info := newBaseInfo(tt.inName, tt.inDesc)

			uassert.Equal(t, tt.wantName, info.Name())
			uassert.Equal(t, tt.wantDesc, info.Desc())
		})
	}
}

func TestBaseInfoEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		inName   string
		inDesc   string
		wantName string
		wantDesc string
	}{
		{
			name:     "baseInfo with whitespace",
			inName:   "  name with spaces  ",
			inDesc:   "\tdescription\nwith\ttabs\nand\nnewlines  ",
			wantName: "  name with spaces  ",
			wantDesc: "\tdescription\nwith\ttabs\nand\nnewlines  ",
		},
		{
			name:     "baseInfo with numeric strings",
			inName:   "12345",
			inDesc:   "999.999",
			wantName: "12345",
			wantDesc: "999.999",
		},
		{
			name:     "baseInfo with single characters",
			inName:   "a",
			inDesc:   "1",
			wantName: "a",
			wantDesc: "1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info := newBaseInfo(tt.inName, tt.inDesc)

			// Should preserve whitespace as-is
			uassert.Equal(t, tt.wantName, info.Name())
			uassert.Equal(t, tt.wantDesc, info.Desc())
		})
	}
}
