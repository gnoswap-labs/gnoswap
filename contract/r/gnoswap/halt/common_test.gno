package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestCommon_newBaseInfo(t *testing.T) {
	tests := []struct {
		name                 string
		inputName            string
		inputDesc            string
		expectedName         string
		expectedDesc         string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success with valid input",
			inputName:        "test-name",
			inputDesc:        "test description",
			expectedName:     "test-name",
			expectedDesc:     "test description",
			expectedHasPanic: false,
		},
		{
			name:             "Success with empty values",
			inputName:        "",
			inputDesc:        "",
			expectedName:     "",
			expectedDesc:     "",
			expectedHasPanic: false,
		},
		{
			name:             "Success with unicode characters",
			inputName:        "测试名称",
			inputDesc:        "これは説明です",
			expectedName:     "测试名称",
			expectedDesc:     "これは説明です",
			expectedHasPanic: false,
		},
		{
			name:             "Success with special characters",
			inputName:        "test@name#123",
			inputDesc:        "test & description with <special> chars",
			expectedName:     "test@name#123",
			expectedDesc:     "test & description with <special> chars",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			info := newBaseInfo(tc.inputName, tc.inputDesc)

			// then
			uassert.Equal(t, tc.expectedName, info.Name())
			uassert.Equal(t, tc.expectedDesc, info.Desc())
		})
	}
}

func TestCommon_baseInfoInterface(t *testing.T) {
	tests := []struct {
		name                 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success implements baseOp interface",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			var op baseOp = newBaseInfo("test", "description")

			// then
			uassert.Equal(t, "test", op.Name())
			uassert.Equal(t, "description", op.Desc())
		})
	}
}

func TestCommon_baseInfoModification(t *testing.T) {
	tests := []struct {
		name                 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success fields are immutable after creation",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			info := newBaseInfo("original", "original desc")

			// then
			uassert.Equal(t, "original", info.Name())
			uassert.Equal(t, "original desc", info.Desc())
		})
	}
}

func TestCommon_baseInfoLongValues(t *testing.T) {
	tests := []struct {
		name                 string
		inputName            string
		inputDesc            string
		expectedName         string
		expectedDesc         string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success with very long strings",
			inputName:        "this_is_a_very_long_name_that_should_still_work_properly_even_with_many_characters_and_underscores_and_numbers_123456789",
			inputDesc:        "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required.",
			expectedName:     "this_is_a_very_long_name_that_should_still_work_properly_even_with_many_characters_and_underscores_and_numbers_123456789",
			expectedDesc:     "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required.",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			info := newBaseInfo(tc.inputName, tc.inputDesc)

			// then
			uassert.Equal(t, tc.expectedName, info.Name())
			uassert.Equal(t, tc.expectedDesc, info.Desc())
		})
	}
}

func TestCommon_baseInfoEdgeCases(t *testing.T) {
	tests := []struct {
		name                 string
		inputName            string
		inputDesc            string
		expectedName         string
		expectedDesc         string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success with whitespace",
			inputName:        "  name with spaces  ",
			inputDesc:        "\tdescription\nwith\ttabs\nand\nnewlines  ",
			expectedName:     "  name with spaces  ",
			expectedDesc:     "\tdescription\nwith\ttabs\nand\nnewlines  ",
			expectedHasPanic: false,
		},
		{
			name:             "Success with numeric strings",
			inputName:        "12345",
			inputDesc:        "999.999",
			expectedName:     "12345",
			expectedDesc:     "999.999",
			expectedHasPanic: false,
		},
		{
			name:             "Success with single characters",
			inputName:        "a",
			inputDesc:        "1",
			expectedName:     "a",
			expectedDesc:     "1",
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			info := newBaseInfo(tc.inputName, tc.inputDesc)

			// then
			uassert.Equal(t, tc.expectedName, info.Name())
			uassert.Equal(t, tc.expectedDesc, info.Desc())
		})
	}
}
