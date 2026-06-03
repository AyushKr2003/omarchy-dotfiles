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

fish_add_path /home/shadow/.spicetify
