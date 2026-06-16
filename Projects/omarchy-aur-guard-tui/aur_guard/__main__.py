from __future__ import annotations
import argparse
from .scanner import get_installed_aur
from .app import AurGuardApp

def main():
    p = argparse.ArgumentParser(description="aur-guard -- Omarchy AUR security scanner TUI")
    p.add_argument("packages", nargs="*", help="Packages to pre-load")
    p.add_argument("--installed","-i", action="store_true", help="Load all installed AUR packages")
    args = p.parse_args()
    preload = list(args.packages)
    if args.installed:
        for pkg in get_installed_aur():
            if pkg not in preload: preload.append(pkg)
    AurGuardApp(preload=preload).run()

if __name__=="__main__":
    main()
