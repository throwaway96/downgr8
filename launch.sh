#!/bin/sh

# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

app_id='lol.downgr8'

toast() {
    escape1="${1//\\/\\\\}"
    escape="${escape1//\"/\\\"}"
    payload="$(printf '{"sourceId":"%s","message":"<h3>downgr8</h3>%s"}' "${app_id}" "${escape}")"
    luna-send-pub -n 1 'luna://com.webos.notification/createToast' "${payload}"
}

toast 'Starting...'

if ! luna-send-pub -n 1 "luna://${app_id}.service/elevate" '{}'; then
    toast 'Luna call failed: elevate.'
fi

pid="$(pidof 'update')"
payload="$(printf '{"pid":"%u"}' "${pid}")"

if ! luna-send-pub -n 1 "luna://${app_id}.service/patch" "${payload}"; then
    toast 'Luna call failed: patch.'
fi

if ! luna-send-pub -n 1 "luna://${app_id}.service/restart" '{}'; then
    toast 'Luna call failed: restart.'
fi
