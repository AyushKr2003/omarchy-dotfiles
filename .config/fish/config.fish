if status is-interactive
    # Commands to run in interactive sessions can go here

    # Yazi wrapper to preserve cwd
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if test -s "$tmp"
            cd (cat "$tmp")
        end
        rm -f "$tmp"
    end

end

function full_sys 
  fastfetch -c  ~/.config/fastfetch/full_sys.jsonc; printf '\e[?24l'; stty -icanon -echo; dd bs=1 count=1 >/dev/null 2>&1; stty icanon echo; printf '\e[?25h'  # size 1120, 680
end

fish_add_path /home/shadow/.spicetify
