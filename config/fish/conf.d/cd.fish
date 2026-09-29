# zoxide-backed cd that keeps fish's dirprev/dirnext history (omarchy-fish PR #6/#7).
# Load fish's stock cd (embedded in the fish 4 binary) explicitly: the installed omarchy-fish still ships a
# vendor cd.fish (cd -> zd), and autoloading that one here would recurse.
status get-file functions/cd.fish | source
functions -c cd __original_cd

function cd --wraps=zd --description 'alias cd=zd'
  zd $argv
end

function zd --description 'zoxide-backed cd'
  if test (count $argv) -eq 0
      __original_cd ~; and return
  else if test -d $argv[1]
      __original_cd -- $argv[1]
  else
      z $argv; and printf "\U000F17A9 "; and pwd || echo "Error: Directory not found"
  end
end
