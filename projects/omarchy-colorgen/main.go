// Command omarchy-colorgen turns a wallpaper into an Omarchy theme using iris.
//
// Interactive:  omarchy-colorgen
// Headless:     omarchy-colorgen --generate <wallpaper> [--light] [--name NAME]
//
//	[--apply] [--export PATH]
package main

import (
	"flag"
	"fmt"
	"os"

	"omarchy-colorgen/internal/iris"
	"omarchy-colorgen/internal/omarchy"
	"omarchy-colorgen/internal/palette"
	"omarchy-colorgen/internal/ui"
	"omarchy-colorgen/internal/wallpaper"
)

var version = "0.1.0"

func main() {
	var (
		genPath    string
		light      bool
		name       string
		apply      bool
		exportPath string
		showVer    bool
	)

	flag.StringVar(&genPath, "generate", "", "headless: generate a theme from this wallpaper and exit")
	flag.StringVar(&genPath, "g", "", "shorthand for --generate")
	flag.BoolVar(&light, "light", false, "headless: generate a light theme (default dark)")
	flag.StringVar(&name, "name", "", "headless: theme name to save under ~/.config/omarchy/themes")
	flag.BoolVar(&apply, "apply", false, "headless: run omarchy-theme-set after saving (implies --name)")
	flag.StringVar(&exportPath, "export", "", "headless: write colors.toml to this path")
	flag.BoolVar(&showVer, "version", false, "print version and exit")
	flag.Parse()

	if showVer {
		fmt.Printf("omarchy-colorgen %s\n", version)
		return
	}

	if !iris.Available() {
		fmt.Fprintln(os.Stderr, "error:", iris.ErrNotInstalled)
		os.Exit(1)
	}

	if genPath != "" {
		if err := runHeadless(genPath, light, name, apply, exportPath); err != nil {
			fmt.Fprintln(os.Stderr, "error:", err)
			os.Exit(1)
		}
		return
	}

	runTUI(light)
}

func runHeadless(path string, light bool, name string, apply bool, exportPath string) error {
	if _, ok := wallpaper.FromPath(path); !ok {
		return fmt.Errorf("%s is not a readable image", path)
	}
	mode := iris.Dark
	if light {
		mode = iris.Light
	}

	t, err := iris.Generate(path, mode)
	if err != nil {
		return err
	}
	pal := palette.FromIris(t)

	if exportPath != "" {
		if err := omarchy.Build(exportPath, pal, path, ""); err != nil {
			return err
		}
		fmt.Println("exported theme folder →", exportPath)
	}

	if apply && name == "" {
		return fmt.Errorf("--apply requires --name")
	}

	if name != "" {
		dir, err := omarchy.WriteTheme(name, pal, path, "")
		if err != nil {
			return err
		}
		fmt.Println("saved theme →", dir)
		if apply {
			if err := omarchy.Apply(name); err != nil {
				return err
			}
			fmt.Printf("applied theme '%s'\n", omarchy.Slug(name))
		}
	}

	if exportPath == "" && name == "" {
		// No output target: print the colors.toml to stdout.
		fmt.Print(omarchy.ColorsTOML(pal, path))
	}
	return nil
}

func runTUI(light bool) {
	mode := iris.Dark
	if light {
		mode = iris.Light
	}
	if err := ui.Run(ui.New(mode)); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
