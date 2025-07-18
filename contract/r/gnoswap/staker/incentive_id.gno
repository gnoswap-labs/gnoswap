package staker

import (
	"bytes"
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
)

// incentiveIdCompute generates a unique incentive ID by combining caller address,
// target pool path, reward token, and time/height information.
//
// The generated ID is a Base64-encoded string of the following format:
// "caller:targetPoolPath:rewardToken:startTimestamp:endTimestamp:height".
//
// Parameters:
// - caller (std.Address): The address of the caller initiating the incentive.
// - targetPoolPath (string): The target pool path for the incentive.
// - rewardToken (string): The reward token associated with the incentive.
// - startTimestamp (int64): The starting timestamp of the incentive.
// - endTimestamp (int64): The ending timestamp of the incentive.
// - height (int64): The blockchain height at which the incentive is created.
//
// Returns:
// - string: A Base64-encoded string representing the unique incentive ID.
//
// Example:
// Input: caller="g1xyz", targetPoolPath="pool1", rewardToken="gns", startTimestamp=12345, endTimestamp=67890, height=1000
// Output: "ZzF4eXo6cG9vbDE6Z25zOjEyMzQ1OjY3ODkwOjEwMDA="
func incentiveIdCompute(caller std.Address, targetPoolPath, rewardToken string, startTimestamp, endTimestamp, height int64) string {
	key := ufmt.Sprintf("%s:%s:%s:%d:%d:%d", caller.String(), targetPoolPath, rewardToken, startTimestamp, endTimestamp, height)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

// writeDelimitedString writes a string followed by a delimiter to the buffer
func writeDelimitedString(buf *bytes.Buffer, s string, delimiter byte) {
	buf.WriteString(s)
	buf.WriteByte(delimiter)
}

// buildIncentiveId builds an incentive ID by joining components with delimiters
func buildIncentiveId(components []string) string {
	var buf bytes.Buffer

	for i, component := range components {
		buf.WriteString(component)
		if i < len(components)-1 {
			buf.WriteByte(':')
		}
	}

	return buf.String()
}

// incentiveIdByTime generates a unique incentive ID based on time intervals,
// creator address, reward token, and target pool path.
//
// The generated ID is a plain string in the following format:
// "startTime:endTime:creator:rewardToken:targetPoolPath".
//
// Parameters:
// - startTime (uint64): The starting time of the incentive.
// - endTime (uint64): The ending time of the incentive.
// - creator (std.Address): The address of the incentive creator.
// - rewardToken (string): The reward token associated with the incentive.
// - targetPoolPath (string): The target pool path for the incentive.
//
// Returns:
// - string: A plain string representing the incentive ID.
//
// Example:
// Input: startTime=12345, endTime=67890, creator="g1xyz", rewardToken="gns", targetPoolPath="pool1"
// Output: "000000000000012345:000000000000067890:g1xyz:gns:pool1"
func incentiveIdByTime(startTime, endTime int64, creator std.Address, rewardToken string, targetPoolPath string) string {
	components := []string{
		EncodeInt64(startTime),
		EncodeInt64(endTime),
		creator.String(),
		rewardToken,
		targetPoolPath,
	}

	return buildIncentiveId(components)
}

// incentiveIdByHeight generates two unique incentive IDs based on height intervals,
// creator address, reward token, and target pool path.
//
// The first ID (byHeightId) has the format:
// "startHeight:endHeight:creator:rewardToken:targetPoolPath".
//
// The second ID (byCreatorId) has the format:
// "creator:startHeight:endHeight:rewardToken:targetPoolPath".
//
// Parameters:
// - startHeight (uint64): The starting blockchain height of the incentive.
// - endHeight (uint64): The ending blockchain height of the incentive.
// - creator (std.Address): The address of the incentive creator.
// - rewardToken (string): The reward token associated with the incentive.
// - targetPoolPath (string): The target pool path for the incentive.
//
// Returns:
// - string: The first ID (byHeightId).
// - string: The second ID (byCreatorId).
//
// Example:
// Input: startHeight=123, endHeight=456, creator="g1xyz", rewardToken="gns", targetPoolPath="pool1"
// Output: "000000000000000123:000000000000000456:g1xyz:gns:pool1", "g1xyz:000000000000000123:000000000000000456:gns:pool1"
func incentiveIdByHeight(startHeight, endHeight int64, creator std.Address, rewardToken string, targetPoolPath string) (string, string) {
	startHeightEncode := EncodeInt64(startHeight)
	endHeightEncode := EncodeInt64(endHeight)
	creatorEncode := creator.String()

	// byHeightId components
	heightComponents := []string{
		startHeightEncode,
		endHeightEncode,
		creatorEncode,
		rewardToken,
		targetPoolPath,
	}

	// byCreatorId components
	creatorComponents := []string{
		creatorEncode,
		startHeightEncode,
		endHeightEncode,
		rewardToken,
		targetPoolPath,
	}

	return buildIncentiveId(heightComponents), buildIncentiveId(creatorComponents)
}
