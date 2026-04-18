# vibecorp 隔離レイヤ activate スクリプト
# 使用: source .claude/bin/activate.sh
# 対応: bash / zsh

_vibecorp_activate() {
  local script_path
  # shellcheck disable=SC2296
  script_path="${BASH_SOURCE[0]:-${(%):-%x}}"
  local bin_abs
  bin_abs="$(cd "$(dirname "$script_path")" && pwd)"
  case ":$PATH:" in
    *":$bin_abs:"*) ;;
    *) PATH="$bin_abs:$PATH"; export PATH ;;
  esac
}
_vibecorp_activate
unset -f _vibecorp_activate
