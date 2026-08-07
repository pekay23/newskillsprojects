package sync

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

type APIClient struct {
	BaseURL    string
	HTTPClient *http.Client
	AuthToken  string
}

func NewAPIClient(baseURL, token string) *APIClient {
	return &APIClient{
		BaseURL:    baseURL,
		AuthToken:  token,
		HTTPClient: &http.Client{},
	}
}

// serviceForEntity maps an entity type to the sync service name
// per SYNC-ENGINE-SPEC Section 6.
func serviceForEntity(entity string) string {
	switch entity {
	case "work_order", "work_order_note", "work_order_photo":
		return "workorders"
	case "asset", "ppm_schedule", "ppm_completion":
		return "cmms"
	case "helpdesk_request", "amenity_booking":
		return "helpdesk"
	default:
		return "workorders"
	}
}

// PushChanges posts the change records to the gateway's /sync/{service} endpoint.
// The gateway routes to the appropriate backend service.
func (c *APIClient) PushChanges(changes []ChangeRecord) error {
	if len(changes) == 0 {
		return nil
	}

	// Group changes by service so we can POST to the correct /sync/{service} endpoint.
	byService := map[string][]ChangeRecord{}
	for _, ch := range changes {
		svc := serviceForEntity(ch.Entity)
		byService[svc] = append(byService[svc], ch)
	}

	for svc, svcChanges := range byService {
		payload, err := json.Marshal(svcChanges)
		if err != nil {
			return fmt.Errorf("failed to marshal changes for %s: %w", svc, err)
		}

		// Per SYNC-ENGINE-SPEC Section 4.1: POST /sync/{service}
		url := c.BaseURL + "/sync/" + svc
		req, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/json")
		if c.AuthToken != "" {
			req.Header.Set("Authorization", "Bearer "+c.AuthToken)
		}

		resp, err := c.HTTPClient.Do(req)
		if err != nil {
			return fmt.Errorf("sync push to %s failed: %w", svc, err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusMultiStatus {
			return fmt.Errorf("sync push to %s failed with status: %s", svc, resp.Status)
		}
	}

	return nil
}