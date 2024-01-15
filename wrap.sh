#!/bin/sh

# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

app_id='lol.downgr8'
logfile='/tmp/downgr8.log'

toast() {
    escape1="${1//\\/\\\\}"
    escape="${escape1//\"/\\\"}"
    payload="$(printf '{"sourceId":"%s","message":"<h3>downgr8</h3>%s"}' "${app_id}" "${escape}")"
    luna-sendpub -n 1 'luna://com.webos.notification/createToast' "${payload}"
}

toast 'Starting...'

# TODO: don't hardcode this
main="/media/developer/apps/usr/palm/applications/lol.downgr8/main"
pid="$(pidof 'update')"

command="$(printf "'%s' '%d' >'%s' 2>&1" "${main}" "${pid}" "${logfile}")"
payload="$(printf '{"command":"%s"}' "${command}")"

luna-send-pub -n 1 'luna://org.webosbrew.hbchannel.service/exec' "${payload}"

if false; then
    toast 'Successfully patched.'
else
    output="$(cat -- "${logfile}")"
    break="${output//
/<br>}"
    toast "Failed. Output (see ${logfile} for more):<br>${break}</p>"
fi
