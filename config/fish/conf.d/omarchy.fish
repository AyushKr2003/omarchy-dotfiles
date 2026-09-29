# Omarchy bash parity (default/bash/envs + env-bootstrap) not covered by omarchy-fish

# Open URLs from terminal programs (like gh) detached from the terminal
set -q BROWSER; or set -gx BROWSER omarchy-launch-browser

# Mirror /etc/profile.d/locale.sh for SSH/herdr sessions that skip login setup
if not set -q LANG; or test -z "$LANG"
    if test -r /etc/locale.conf
        for line in (string match -r '^[A-Z_]+=.*' < /etc/locale.conf)
            set -l kv (string split -m 1 = -- $line)
            set -gx $kv[1] (string trim -c '"\'' -- $kv[2])
        end
    end
    set -q LANG; or set -gx LANG C.UTF-8
end

# User-level tool paths, appended so system binaries keep precedence
for dir in $HOME/.local/share/mise/shims $HOME/.local/bin
    contains -- $dir $PATH; or set -gx PATH $PATH $dir
end
