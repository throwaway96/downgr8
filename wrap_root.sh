#!/bin/sh

# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

app_id='lol.downgr8'
logfile='/tmp/downgr8.log'

# TODO: don't hardcode this
app_dir="/media/developer/apps/usr/palm/applications/${app_id}"

toast() {
    escape1="${1//\\/\\\\}"
    escape="${escape1//\"/\\\"}"
    payload="$(printf '{"sourceId":"%s","message":"<h3>downgr8</h3>%s"}' "${app_id}" "${escape}")"
    luna-send -a "${app_id}" -n 1 'luna://com.webos.notification/createToast' "${payload}"
}

if [ "$(id -u)" -eq 0 ]; then
    toast 'Running as root...'
else
    toast 'Failed! Not running as root.'
    exit 1
fi

main="${app_dir}/main"
pid="$(pidof 'update')"

if "${main}" "${pid}" >"${logfile}" 2>&1; then
    toast 'Successfully patched.'
else
    output="$(cat -- "${logfile}")"
    break="${output//
/<br>}"
    toast "Failed. Output (see ${logfile} for more):<br>${break}</p>"
    exit 1
fi
