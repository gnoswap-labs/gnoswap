package dependency

import (
	"std"

	"gno.land/p/nt/ufmt"
)

// formatVersions formats a version list to a comma-separated string.
func formatVersions(versions []Version) string {
	if len(versions) == 0 {
		return ""
	}

	result := ufmt.Sprintf("%d", versions[0])
	for i := 1; i < len(versions); i++ {
		result += ufmt.Sprintf(",%d", versions[i])
	}

	return result
}

// parseVersions parses a comma-separated version string to a version list.
func parseVersions(versionsStr string) []Version {
	if versionsStr == "" {
		return []Version{}
	}

	versions := []Version{}
	current := ""

	for i := 0; i < len(versionsStr); i++ {
		if versionsStr[i] == ',' {
			if current != "" {
				version := parseVersion(current)
				if version > 0 {
					versions = append(versions, version)
				}
				current = ""
			}
		} else {
			current += string(versionsStr[i])
		}
	}

	// Add last version
	if current != "" {
		version := parseVersion(current)
		if version > 0 {
			versions = append(versions, version)
		}
	}

	return versions
}

// parseVersion parses a version string to Version.
func parseVersion(versionStr string) Version {
	result := 0
	for i := 0; i < len(versionStr); i++ {
		digit := int(versionStr[i] - '0')
		if digit < 0 || digit > 9 {
			return 0
		}
		result = result*10 + digit
	}
	return Version(result)
}

// assertIsAdmin checks if the caller is the admin.
func assertIsAdmin(caller std.Address) {
	if caller != ADMIN {
		panic(makeErrorWithDetails(
			errCallerIsNotAdmin,
			ufmt.Sprintf("caller: %s", caller.String()),
		))
	}
}
