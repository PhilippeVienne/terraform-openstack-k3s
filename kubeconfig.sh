#!/bin/bash

function check_deps() {
  test -f "$(command -v jq)" || error_exit "jq command not detected in path, please install it"
}
function parse_input() {
  eval "$(jq -r '@sh "export HOST=\(.controller)"')"
  if [[ -z "${HOST}" ]]; then export HOST=none; fi
}
function return_token() {
  TOKEN=$(ssh -oStrictHostKeyChecking=no ubuntu@$HOST "sudo cat /etc/rancher/k3s/k3s.yaml")
  jq -n \
    --arg token "$TOKEN" \
    '{"kubeconfig":$token}'
}
check_deps && \
parse_input && \}
return_token
