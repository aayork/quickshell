// things-check ticks or unticks one checklist item in Things Cloud, which
// things-cli cannot do. Same login as things-cli (THINGS_USERNAME and
// THINGS_PASSWORD), supplied by bin/things.
//
//	things-check <checklist-item-uuid> on|off
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	thingscloud "github.com/arthursoares/things-cloud-sdk"
)

type update struct {
	id      string
	payload map[string]any
}

func (u update) UUID() string { return u.id }

func (u update) MarshalJSON() ([]byte, error) {
	return json.Marshal(struct {
		T int            `json:"t"`
		E string         `json:"e"`
		P map[string]any `json:"p"`
	}{1, "ChecklistItem3", u.payload})
}

func fail(what string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %v\n", what, err)
	os.Exit(1)
}

func main() {
	if len(os.Args) != 3 || (os.Args[2] != "on" && os.Args[2] != "off") {
		fmt.Fprintln(os.Stderr, "Usage: things-check <checklist-item-uuid> on|off")
		os.Exit(2)
	}
	id, on := os.Args[1], os.Args[2] == "on"
	if err := thingscloud.ValidateUUID(id); err != nil {
		fail("check", err)
	}

	endpoint := thingscloud.APIEndpoint
	if v := os.Getenv("THINGS_ENDPOINT"); v != "" {
		endpoint = v
	}
	c := thingscloud.New(endpoint, os.Getenv("THINGS_USERNAME"), os.Getenv("THINGS_PASSWORD"))
	if _, err := c.Verify(); err != nil {
		fail("login", err)
	}
	history, err := c.OwnHistory()
	if err != nil {
		fail("get history", err)
	}
	if err := history.Sync(); err != nil {
		fail("sync history", err)
	}

	now := float64(time.Now().UnixNano()) / 1e9
	p := map[string]any{"md": now, "ss": 0, "sp": nil}
	if on {
		p["ss"], p["sp"] = 3, now
	}
	if err := history.Write(update{id: id, payload: p}); err != nil {
		fail("check", err)
	}
}
