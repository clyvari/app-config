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

SCRIPTS="$(realpath "${SCRIPT_DIR}/scripts")"

if [[ -z "${APPCFG_PKGSRC:+u}" ]]; then
  APPCFG_PKGSRC="${1:?The APPCFG_PKGSRC argument is missing}"; shift
fi

APP="${1:?The APP argument is missing}"; shift
APPDIR="${APPCFG_PKGSRC}/${APP}"
if [[ ! -d "${APPDIR}"  ]]; then
  error "Application ${APP} not found in \`$(pwd)/${APPCFG_PKGSRC}\`"
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
    stow . \
        --dir="${pkgdir}" \
        --target="${INSTALL_DIR}" \
        --stow \
        --ignore='\.((install|condition).sh|env)' \
        --dotfiles \
        --adopt
  fi
}

pushd "${APPDIR}" >/dev/null

export PATH="${PATH}:${SCRIPTS}"

if [[ ! -z "${MULTI_TARGET:+u}" ]]; then
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
else
  install_pkg "${APP}" "${APPDIR}"
fi




# popd >/dev/null
# if [[ -f "${APPDIR}/.install.sh" ]]; then
#   pushd "${APPDIR}" >/dev/null
#   info "Installing using install script"
#   "./.install.sh"
#   popd >/dev/null
# else
#   if [[ -z "${INSTALL_DIR}" ]]; then
#     error "\$INSTALL_DIR can't be empty"
#     exit 1
#   fi
#   mkdir -p "${INSTALL_DIR}"
#   info "Stowing content of ${APP} to ${INSTALL_DIR}"
#   stow . \
#        --dir="${APPDIR}" \
#        --target="${INSTALL_DIR}" \
#        --stow \
#        --ignore='\.((install|condition).sh|env)' \
#        --dotfiles \
#        --adopt
# fi

info "DONE"
