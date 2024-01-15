#!/bin/sh

# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

app_id='lol.downgr8'

# TODO: don't hardcode this
app_dir="/media/developer/apps/usr/palm/applications/${app_id}"

toast() {
    escape1="${1//\\/\\\\}"
    escape="${escape1//\"/\\\"}"
    payload="$(printf '{"sourceId":"%s","message":"<h3>downgr8</h3>%s"}' "${app_id}" "${escape}")"
    luna-send-pub -n 1 'luna://com.webos.notification/createToast' "${payload}"
}

toast 'Starting...'

wrap_root="${app_dir}/wrap_root"

payload="$(printf '{"command":"'%s'"}' "${wrap_root}")"

if ! luna-send-pub -n 1 'luna://org.webosbrew.hbchannel.service/exec' "${payload}"; then
    toast 'Failed to execute next stage.'
fi
