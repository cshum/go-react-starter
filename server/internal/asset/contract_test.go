package asset

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// fixturePath walks up until it finds testdata/asset.json, so the test works whether the
// module sits at the repo root or one directory down.
func fixturePath(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	for {
		candidate := filepath.Join(dir, "testdata", "asset.json")
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("testdata/asset.json not found above the working directory")
		}
		dir = parent
	}
}

// TestJSONContract pins the wire shape against the fixture the web tests decode.
func TestJSONContract(t *testing.T) {
	raw, err := os.ReadFile(fixturePath(t))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	var a Asset
	if err := json.Unmarshal(raw, &a); err != nil {
		t.Fatalf("decode fixture: %v", err)
	}
	if a.ID == "" || a.Filename == "" || a.SHA256 == "" || a.Size == 0 || a.CreatedAt.IsZero() {
		t.Fatalf("fixture left a field zero: %+v", a)
	}

	encoded, err := json.Marshal(a)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	var want, got map[string]any
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(encoded, &got); err != nil {
		t.Fatal(err)
	}
	for k := range want {
		if _, ok := got[k]; !ok {
			t.Errorf("Asset is missing %q from the fixture", k)
		}
	}
	for k := range got {
		if _, ok := want[k]; !ok {
			t.Errorf("Asset encodes %q which the fixture does not have", k)
		}
	}
}
