package e2e

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func httpGet(url string) ([]byte, error) {
	const maxRetries = 3
	var lastErr error
	for i := range maxRetries {
		if i > 0 {
			time.Sleep(time.Duration(i) * time.Second)
		}
		resp, err := http.Get(url)
		if err != nil {
			lastErr = err
			continue
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}
		if resp.StatusCode == http.StatusServiceUnavailable {
			lastErr = fmt.Errorf("HTTP 503 from %s", url)
			continue
		}
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("HTTP %d from %s: %s", resp.StatusCode, url, string(body))
		}
		return body, nil
	}
	return nil, lastErr
}

func gnoQuery(containerID, rpcEndpoint, realmPath, renderArgs string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	data := fmt.Sprintf("gno.land/%s:%s", realmPath, renderArgs)
	stdout, stderr, err := dockerExec(ctx, containerID,
		"gnokey", "query", "vm/qrender",
		"-data", data,
		"-remote", rpcEndpoint,
	)
	if err != nil {
		return "", fmt.Errorf("gnokey query %s: %w: %s", data, err, stderr)
	}
	const prefix = "data: "
	idx := strings.Index(stdout, prefix)
	if idx < 0 {
		return "", fmt.Errorf("unexpected gnokey output (no 'data: ' prefix): %s", stdout)
	}
	content := strings.TrimSpace(stdout[idx+len(prefix):])
	return content, nil
}

func queryAtomOneClientStates(restURL string) (string, error) {
	body, err := httpGet(restURL + "/ibc/core/client/v1/client_states")
	if err != nil {
		return "", err
	}
	var resp struct {
		ClientStates []struct {
			ClientID string `json:"client_id"`
		} `json:"client_states"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		return "", fmt.Errorf("parse client_states: %w", err)
	}
	if len(resp.ClientStates) == 0 {
		return "", fmt.Errorf("no client states found")
	}
	return resp.ClientStates[0].ClientID, nil
}

func queryGnoClients(containerID, rpcEndpoint string) (string, error) {
	content, err := gnoQuery(containerID, rpcEndpoint, "r/aib/ibc/core", "clients")
	if err != nil {
		return "", err
	}
	var resp struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	if err := json.Unmarshal([]byte(content), &resp); err != nil {
		return "", fmt.Errorf("parse gno clients: %w (raw: %s)", err, content)
	}
	if len(resp.Items) == 0 {
		return "", fmt.Errorf("no clients found on gno")
	}
	return resp.Items[0].ID, nil
}

func queryGnoClientCounterparty(containerID, rpcEndpoint, clientID string) (string, error) {
	content, err := gnoQuery(containerID, rpcEndpoint, "r/aib/ibc/core", "clients/"+clientID)
	if err != nil {
		return "", err
	}
	var resp struct {
		CounterpartyClientID string `json:"counterparty_client_id"`
	}
	if err := json.Unmarshal([]byte(content), &resp); err != nil {
		return "", fmt.Errorf("parse client counterparty: %w (raw: %s)", err, content)
	}
	if resp.CounterpartyClientID == "" {
		return "", fmt.Errorf("no counterparty registered for %s", clientID)
	}
	return resp.CounterpartyClientID, nil
}

func queryGnoGRC20Balance(containerID, rpcEndpoint, addr, denom string) (int64, error) {
	renderArgs := fmt.Sprintf("grc20/%s/balance/%s", denom, addr)
	content, err := gnoQuery(containerID, rpcEndpoint, "r/aib/ibc/apps/transfer", renderArgs)
	if err != nil {
		return 0, err
	}
	var resp struct {
		Balance json.Number `json:"balance"`
	}
	if err := json.Unmarshal([]byte(content), &resp); err != nil {
		return 0, fmt.Errorf("parse GRC20 balance: %w (raw: %s)", err, content)
	}
	bal, err := strconv.ParseInt(string(resp.Balance), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("parse balance number: %w", err)
	}
	return bal, nil
}

func queryGnoBalance(containerID, rpcEndpoint, addr, denom string) (int64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	stdout, stderr, err := dockerExec(ctx, containerID,
		"gnokey", "query", "bank/balances/"+addr,
		"-remote", rpcEndpoint,
	)
	if err != nil {
		return 0, fmt.Errorf("gnokey query bank/balances: %w: %s", err, stderr)
	}
	const prefix = "data: "
	idx := strings.Index(stdout, prefix)
	if idx < 0 {
		return 0, fmt.Errorf("unexpected output (no 'data: ' prefix): %s", stdout)
	}
	data := strings.Trim(strings.TrimSpace(stdout[idx+len(prefix):]), "\"")
	for coin := range strings.SplitSeq(data, ",") {
		if strings.HasSuffix(coin, denom) {
			amountStr := strings.TrimSuffix(coin, denom)
			return strconv.ParseInt(amountStr, 10, 64)
		}
	}
	return 0, nil
}

func queryAtomOneBalance(restURL, addr, denom string) (int64, error) {
	url := fmt.Sprintf("%s/cosmos/bank/v1beta1/balances/%s/by_denom?denom=%s", restURL, addr, denom)
	body, err := httpGet(url)
	if err != nil {
		return 0, err
	}
	var resp struct {
		Balance struct {
			Amount string `json:"amount"`
		} `json:"balance"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		return 0, fmt.Errorf("parse balance: %w", err)
	}
	if resp.Balance.Amount == "" {
		return 0, nil
	}
	return strconv.ParseInt(resp.Balance.Amount, 10, 64)
}

func computeIBCDenomHash(clientID, denom string) string {
	path := fmt.Sprintf("transfer/%s/%s", clientID, denom)
	hash := sha256.Sum256([]byte(path))
	return strings.ToUpper(fmt.Sprintf("%x", hash))
}
