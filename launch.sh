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

# use Homebrew Channel's elevate-service on self if not already running as root
if ! luna-send-pub -n 1 "luna://${app_id}.service/elevate" '{}'; then
    toast 'Luna call failed: elevate.'
fi

# make sure the service uses the new permissions if it was elevated
if ! luna-send-pub -n 1 "luna://${app_id}.service/quit" '{}'; then
    toast 'Luna call failed: quit.'
fi

# this is not strictly necessary, as the handler will run 'pidof update' itself
# when "pid" is not passed
pid="$(pidof 'update')"
payload="$(printf '{"pid":"%u"}' "${pid}")"

if ! luna-send-pub -n 1 "luna://${app_id}.service/patch" "${payload}"; then
    toast 'Luna call failed: patch.'
fi

# restart securitymanager
if ! luna-send-pub -n 1 "luna://${app_id}.service/restart" '{}'; then
    toast 'Luna call failed: restart.'
fi

# vim: noet:ts=4:sw=9:
