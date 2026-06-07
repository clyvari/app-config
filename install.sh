#!/bin/bash
set -eu

SCRIPT_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd)"



function log(){
  local lvl="${1}"; shift || true
  echo "[${lvl}] $@"
}
function error(){
  log "ERR " "$@"
}
function warn(){
  log "WARN" "$@"
}
function info(){
  log "    " "$@"
}
function logcnt(){
  echo "       $@"
}

if [[ -z "${1:+u}" ]]; then
  info "Installing self in ${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}"
  cat <<EOF > "${INSTALL_DIR}/app-install"
#!/bin/bash
set -eu
"${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")" "\$@"
EOF
  chmod +x "${INSTALL_DIR}/app-install"
  # ln -s -f -T "${SCRIPT_DIR}/install.sh" "${INSTALL_DIR}/app-install"
  exit 0
fi

case "${1}" in
  help|--help|-h)
    cat <<'EOF'
This script either install itself or another app.

To install itself:
  `INSTALL_DIR=dir ./install.sh` without any argument

To install an other app:
  `INSTALL_DIR=dir APPCFG_PKGSRC=pkgsrc ./install.sh app`
   or by passing the package source as an argument: `INSTALL_DIR=dir ./install.sh pkgsrc app`

where:
  - `pkgsrc` is the directory holding the app packages
  - `app`    is the package to install (a sub-directory of `pkgsrc`)

Notes:
  - `INSTALL_DIR` is the target the package is stowed into; it is
    required unless the package ships its own `.install.sh`.
  - Positional arguments take precedence over `APPCFG_PKGSRC`, so
    `./install.sh pkgsrc app` works whether or not the variable is set.
  - If the resolved package directory contains multiple candidates,
    set `MULTI_TARGET` to select among them via their `.condition.sh`.
EOF
  exit 0
  ;;
esac

SCRIPTS="$(realpath "${SCRIPT_DIR}/scripts")"

if [[ -z "${APPCFG_PKGSRC:+u}" ]]; then
  APPCFG_PKGSRC="${1:?The APPCFG_PKGSRC argument is missing}"; shift
fi

APP="${1:?The APP argument is missing}"; shift

FINAL_ARG="${1:-}"; shift || true

if [[ ! -z "${FINAL_ARG:+u}" ]]; then
  APPCFG_PKGSRC="${APP}"
  APP="${FINAL_ARG}"
fi

APPDIR="${APPCFG_PKGSRC}/${APP}"
if [[ ! -d "${APPDIR}"  ]]; then
  error "Application ${APP} not found in \`${APPCFG_PKGSRC}\`"
  exit 1
fi

if [[ -f "${APPDIR}/.env" ]]; then
  set -a # auto export
  . "${APPDIR}/.env"
  set +a
fi


function install_pkg(){
  local app="${1}"; shift
  local pkgdir="${1}"; shift

  if [[ -f "${pkgdir}/.install.sh" ]]; then
    pushd "${pkgdir}" >/dev/null
    info "Installing using install script"
    "./.install.sh"
    popd >/dev/null
  else
    if [[ -z "${INSTALL_DIR}" ]]; then
      error "\$INSTALL_DIR can't be empty"
      exit 1
    fi
    mkdir -p "${INSTALL_DIR}"
    info "Stowing content of ${app} to ${INSTALL_DIR}"
    info "Current dir: $(pwd)"
    stow . \
        --dir="${pkgdir}" \
        --target="${INSTALL_DIR}" \
        --stow \
        "$([[ "${NO_FOLDING}" == "y" ]] && echo "--no-folding")" \
        --ignore='\.((install|condition).sh|env)' \
        --dotfiles \
        --adopt
  fi
}


export PATH="${PATH}:${SCRIPTS}"

if [[ ! -z "${MULTI_TARGET:+u}" ]]; then
  pushd "${APPDIR}" >/dev/null
  info "App \`${APP}\` has multiple candidates"
  for c in *; do
    if [[ ! -f "${c}/.condition.sh" ]] || "${c}/.condition.sh"; then
      logcnt "Candidate ${c} has been selected"
      CFOUND=y

      popd >/dev/null

      install_pkg "${APP}" "${APPDIR}/${c}"

      pushd "${APPDIR}" >/dev/null

    fi
  done
  if [[ -z "${CFOUND:+u}" ]]; then
    error "No candidate found"
    exit 1
  fi
  popd >/dev/null
else
  install_pkg "${APP}" "${APPDIR}"
fi

info "DONE"
