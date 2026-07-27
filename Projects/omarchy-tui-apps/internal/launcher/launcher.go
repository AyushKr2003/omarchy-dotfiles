package launcher

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

func LaunchApp(id, desktopFile string) error {
	if p, err := exec.LookPath("gtk-launch"); err == nil {
		if exec.Command(p, id).Start() == nil {
			return nil
		}
	}
	if p, err := exec.LookPath("gio"); err == nil {
		if exec.Command(p, "launch", desktopFile).Start() == nil {
			return nil
		}
	}
	line := RawExec(desktopFile)
	if line == "" {
		return fmt.Errorf("no Exec= in %s", desktopFile)
	}
	var parts []string
	for _, p := range strings.Fields(line) {
		if len(p) == 2 && p[0] == '%' {
			continue
		}
		parts = append(parts, p)
	}
	if len(parts) == 0 {
		return fmt.Errorf("empty exec")
	}
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd.Start()
}

func RawExec(desktopFile string) string {
	f, err := os.Open(desktopFile)
	if err != nil {
		return ""
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if strings.HasPrefix(line, "Exec=") {
			return strings.TrimPrefix(line, "Exec=")
		}
	}
	return ""
}
