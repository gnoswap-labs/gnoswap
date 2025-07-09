package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestOpType(t *testing.T) {
	t.Run("OpType string representation", func(t *testing.T) {
		uassert.Equal(t, "pool", OpTypePool.String())
		uassert.Equal(t, "position", OpTypePosition.String())
		uassert.Equal(t, "protocol_fee", OpTypeProtocolFee.String())
		uassert.Equal(t, "router", OpTypeRouter.String())
		uassert.Equal(t, "staker", OpTypeStaker.String())
		uassert.Equal(t, "launchpad", OpTypeLaunchpad.String())
		uassert.Equal(t, "governance", OpTypeGovernance.String())
		uassert.Equal(t, "gov_staker", OpTypeGovStaker.String())
		uassert.Equal(t, "xgns", OpTypeXGns.String())
		uassert.Equal(t, "community_pool", OpTypeCommunityPool.String())
		uassert.Equal(t, "emission", OpTypeEmission.String())
		uassert.Equal(t, "withdraw", OpTypeWithdraw.String())
	})

	t.Run("OpType constants match raw constants", func(t *testing.T) {
		uassert.Equal(t, rawPool, string(OpTypePool))
		uassert.Equal(t, rawPosition, string(OpTypePosition))
		uassert.Equal(t, rawProtocolFee, string(OpTypeProtocolFee))
		uassert.Equal(t, rawRouter, string(OpTypeRouter))
		uassert.Equal(t, rawStaker, string(OpTypeStaker))
		uassert.Equal(t, rawLaunchpad, string(OpTypeLaunchpad))
		uassert.Equal(t, rawGovernance, string(OpTypeGovernance))
		uassert.Equal(t, rawGovStaker, string(OpTypeGovStaker))
		uassert.Equal(t, rawXGns, string(OpTypeXGns))
		uassert.Equal(t, rawCommunityPool, string(OpTypeCommunityPool))
		uassert.Equal(t, rawEmission, string(OpTypeEmission))
		uassert.Equal(t, rawWithdraw, string(OpTypeWithdraw))
	})

	t.Run("custom OpType", func(t *testing.T) {
		customOp := OpType("custom_operation")
		uassert.Equal(t, "custom_operation", customOp.String())
	})

	t.Run("empty OpType", func(t *testing.T) {
		emptyOp := OpType("")
		uassert.Equal(t, "", emptyOp.String())
	})
}

func TestBasicOperation(t *testing.T) {
	t.Run("NewOperation creates valid basicOperation", func(t *testing.T) {
		op := NewOperation(OpTypePool, "Pool Management", "Manages pool operations")

		uassert.True(t, op.Type() == OpTypePool)
		uassert.Equal(t, "Pool Management", op.Name())
		uassert.Equal(t, "Manages pool operations", op.Desc())
	})

	t.Run("basicOperation with empty values", func(t *testing.T) {
		op := NewOperation(OpType(""), "", "")

		uassert.True(t, op.Type() == OpType(""))
		uassert.Equal(t, "", op.Name())
		uassert.Equal(t, "", op.Desc())
	})

	t.Run("basicOperation with custom OpType", func(t *testing.T) {
		customType := OpType("custom_type")
		op := NewOperation(customType, "Custom Operation", "Custom description")

		uassert.True(t, op.Type() == customType)
		uassert.Equal(t, "Custom Operation", op.Name())
		uassert.Equal(t, "Custom description", op.Desc())
	})

	t.Run("basicOperation implements Operation interface", func(t *testing.T) {
		var op Operation = NewOperation(OpTypePool, "Pool", "Pool operations")

		uassert.True(t, op.Type() == OpTypePool)
		uassert.Equal(t, "Pool", op.Name())
		uassert.Equal(t, "Pool operations", op.Desc())
	})

	t.Run("basicOperation implements baseOp interface", func(t *testing.T) {
		var baseOp baseOp = NewOperation(OpTypePool, "Pool", "Pool operations")

		uassert.Equal(t, "Pool", baseOp.Name())
		uassert.Equal(t, "Pool operations", baseOp.Desc())
	})

	t.Run("multiple operations with same type", func(t *testing.T) {
		op1 := NewOperation(OpTypePool, "Pool Op 1", "First pool operation")
		op2 := NewOperation(OpTypePool, "Pool Op 2", "Second pool operation")

		// Both should have same type but different names/descriptions
		uassert.True(t, op1.Type() == OpTypePool)
		uassert.True(t, op2.Type() == OpTypePool)
		uassert.Equal(t, "Pool Op 1", op1.Name())
		uassert.Equal(t, "Pool Op 2", op2.Name())
		uassert.Equal(t, "First pool operation", op1.Desc())
		uassert.Equal(t, "Second pool operation", op2.Desc())
	})
}

func TestOperationWithSpecialCharacters(t *testing.T) {
	t.Run("operation with unicode characters", func(t *testing.T) {
		op := NewOperation(OpType("测试"), "测试操作", "这是一个测试操作")

		uassert.True(t, op.Type() == OpType("测试"))
		uassert.Equal(t, "测试操作", op.Name())
		uassert.Equal(t, "这是一个测试操作", op.Desc())
	})

	t.Run("operation with special characters", func(t *testing.T) {
		op := NewOperation(OpType("op@type#1"), "Op & Name", "Description with <special> chars")

		uassert.True(t, op.Type() == OpType("op@type#1"))
		uassert.Equal(t, "Op & Name", op.Name())
		uassert.Equal(t, "Description with <special> chars", op.Desc())
	})

	t.Run("operation with whitespace", func(t *testing.T) {
		op := NewOperation(OpType("  spaced  "), "  Name  ", "  Description  ")

		uassert.True(t, op.Type() == OpType("  spaced  "))
		uassert.Equal(t, "  Name  ", op.Name())
		uassert.Equal(t, "  Description  ", op.Desc())
	})

	t.Run("operation with newlines and tabs", func(t *testing.T) {
		op := NewOperation(OpType("type\nwith\nnewlines"), "Name\twith\ttabs", "Description\nwith\nmixed\twhitespace")

		uassert.True(t, op.Type() == OpType("type\nwith\nnewlines"))
		uassert.Equal(t, "Name\twith\ttabs", op.Name())
		uassert.Equal(t, "Description\nwith\nmixed\twhitespace", op.Desc())
	})
}

func TestOperationComparison(t *testing.T) {
	t.Run("operations with same type are equal", func(t *testing.T) {
		op1 := NewOperation(OpTypePool, "Pool 1", "First pool")
		op2 := NewOperation(OpTypePool, "Pool 2", "Second pool")

		uassert.True(t, op1.Type() == op2.Type())
	})

	t.Run("operations with different types are not equal", func(t *testing.T) {
		op1 := NewOperation(OpTypePool, "Pool", "Pool operation")
		op2 := NewOperation(OpTypePosition, "Position", "Position operation")

		uassert.True(t, op1.Type() != op2.Type())
	})

	t.Run("operation type comparison with string", func(t *testing.T) {
		op := NewOperation(OpTypePool, "Pool", "Pool operation")

		uassert.Equal(t, "pool", string(op.Type()))
		uassert.Equal(t, "pool", op.Type().String())
	})
}

func TestOperationEdgeCases(t *testing.T) {
	t.Run("operation with very long strings", func(t *testing.T) {
		longType := OpType("very_long_operation_type_that_exceeds_normal_length_expectations_and_continues_for_a_very_long_time")
		longName := "Very Long Operation Name That Exceeds Normal Length Expectations And Continues For A Very Long Time"
		longDesc := "This is a very long description that spans multiple lines and contains various types of information including technical details, explanations, and examples that might be used in real-world scenarios where detailed documentation is required for complex operations."

		op := NewOperation(longType, longName, longDesc)

		uassert.True(t, op.Type() == longType)
		uassert.Equal(t, longName, op.Name())
		uassert.Equal(t, longDesc, op.Desc())
	})

	t.Run("operation with numeric strings", func(t *testing.T) {
		op := NewOperation(OpType("12345"), "999", "1.23e10")

		uassert.True(t, op.Type() == OpType("12345"))
		uassert.Equal(t, "999", op.Name())
		uassert.Equal(t, "1.23e10", op.Desc())
	})

	t.Run("operation with single character values", func(t *testing.T) {
		op := NewOperation(OpType("a"), "b", "c")

		uassert.True(t, op.Type() == OpType("a"))
		uassert.Equal(t, "b", op.Name())
		uassert.Equal(t, "c", op.Desc())
	})
}

func TestOperationInterfaceCompliance(t *testing.T) {
	t.Run("verify Operation interface compliance", func(t *testing.T) {
		// This test ensures that basicOperation properly implements Operation interface
		var op Operation = NewOperation(OpTypePool, "Pool", "Pool operations")

		// Test Operation interface methods
		uassert.True(t, op.Type() == OpTypePool)

		// Test baseOp interface methods (inherited)
		uassert.Equal(t, "Pool", op.Name())
		uassert.Equal(t, "Pool operations", op.Desc())
	})

	t.Run("verify baseOp interface compliance", func(t *testing.T) {
		// This test ensures that basicOperation properly implements baseOp interface
		var baseOp baseOp = NewOperation(OpTypePool, "Pool", "Pool operations")

		// Test baseOp interface methods
		uassert.Equal(t, "Pool", baseOp.Name())
		uassert.Equal(t, "Pool operations", baseOp.Desc())
	})

	t.Run("interface method consistency", func(t *testing.T) {
		basicOp := NewOperation(OpTypePool, "Pool", "Pool operations")

		// Cast to both interfaces and verify same results
		var op Operation = basicOp
		var baseOp baseOp = basicOp

		uassert.Equal(t, op.Name(), baseOp.Name())
		uassert.Equal(t, op.Desc(), baseOp.Desc())
	})
}
