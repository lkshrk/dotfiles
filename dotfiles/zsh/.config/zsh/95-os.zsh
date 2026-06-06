# Load OS-specific config from os.d/<os>/*.zsh (name order).
# Lives in the shared zsh package, so this dispatch exists on every host.
case $OSTYPE in
  darwin*) _os=darwin ;;
  linux*)  _os=linux  ;;
  *)       _os=$OSTYPE ;;
esac
for _f in "${0:A:h}/os.d/$_os"/*.zsh(N); do
  source "$_f"
done
unset _f _os
