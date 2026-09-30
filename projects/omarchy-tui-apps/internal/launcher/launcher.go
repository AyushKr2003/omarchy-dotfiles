package launcher

import (
	"fmt"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"omarchy-tui-apps/internal/desktop"
)

// LaunchApp starts app detached from the launcher's terminal, so it keeps
// running after the launcher (and the window hosting it) closes.
func LaunchApp(app desktop.AppItem) error {
	if p, err := exec.LookPath("gtk-launch"); err == nil {
		if runHelper(p, app.ID) == nil {
			return nil
		}
	}
	if p, err := exec.LookPath("gio"); err == nil {
		if runHelper(p, "launch", app.DesktopFile) == nil {
			return nil
		}
	}

	line := stripFieldCodes(app.Exec)
	if line == "" {
		return fmt.Errorf("no Exec= in %s", app.DesktopFile)
	}
	cmd := detached("sh", "-c", line)
	if app.Terminal {
		term, err := exec.LookPath("xdg-terminal-exec")
		if err != nil {
			return fmt.Errorf("%s needs a terminal but xdg-terminal-exec is missing", app.Name)
		}
		cmd = detached(term, "sh", "-c", line)
	}
	return cmd.Start()
}

func detached(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd
}

// runHelper runs a launch helper that is expected to spawn the app and exit.
// A helper still running after the grace period counts as a success.
func runHelper(name string, args ...string) error {
	cmd := detached(name, args...)
	if err := cmd.Start(); err != nil {
		return err
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		return err
	case <-time.After(2 * time.Second):
		return nil
	}
}

// stripFieldCodes drops the %f/%U/... placeholders from an Exec line and
// unescapes %%.
func stripFieldCodes(line string) string {
	var sb strings.Builder
	rs := []rune(line)
	for i := 0; i < len(rs); i++ {
		if rs[i] == '%' && i+1 < len(rs) {
			i++
			if rs[i] == '%' {
				sb.WriteRune('%')
			}
			continue
		}
		sb.WriteRune(rs[i])
	}
	return strings.TrimSpace(sb.String())
}
