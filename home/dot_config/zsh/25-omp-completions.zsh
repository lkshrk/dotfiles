# The ~/.local/bin/omp wrapper reads a credential from rbw and blocks on pinentry when the vault is locked.
_omp_bin=${BUN_INSTALL:-$HOME/.bun}/bin/omp
_omp_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/omp-completions.zsh
if [[ -x $_omp_bin ]]; then
  if [[ ! -s $_omp_cache || $_omp_bin:A -nt $_omp_cache ]]; then
    mkdir -p ${_omp_cache:h}
    "$_omp_bin" completions zsh </dev/null >| $_omp_cache 2>/dev/null || : >| $_omp_cache
  fi
  [[ -s $_omp_cache ]] && source $_omp_cache
fi
unset _omp_bin _omp_cache
