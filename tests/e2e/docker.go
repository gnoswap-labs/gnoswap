package e2e

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
)

func getContainerID(service string) (string, error) {
	cmd := exec.Command("docker", "compose", "ps", "-q", service)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("docker compose ps -q %s: %w", service, err)
	}
	id := strings.TrimSpace(string(out))
	if id == "" {
		return "", fmt.Errorf("no container found for service %s", service)
	}
	return id, nil
}

func dockerExec(ctx context.Context, containerID string, args ...string) (string, string, error) {
	cmdArgs := append([]string{"exec", containerID}, args...)
	cmd := exec.CommandContext(ctx, "docker", cmdArgs...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}

func dockerExecStdin(ctx context.Context, containerID string, stdin string, args ...string) (string, string, error) {
	cmdArgs := append([]string{"exec", "-i", containerID}, args...)
	cmd := exec.CommandContext(ctx, "docker", cmdArgs...)
	cmd.Stdin = strings.NewReader(stdin)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}
