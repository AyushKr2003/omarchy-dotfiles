package iris

import "testing"

func TestModeFlag(t *testing.T) {
	if Dark.FlagString() != "1" || Light.FlagString() != "0" || Auto.FlagString() != "-1" {
		t.Errorf("flags: dark=%s light=%s auto=%s", Dark.FlagString(), Light.FlagString(), Auto.FlagString())
	}
	if Dark.Label() != "DARK" || Light.Label() != "LIGHT" || Auto.Label() != "AUTO" {
		t.Errorf("labels wrong")
	}
}
