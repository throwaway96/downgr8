#!/usr/bin/env node

/*
 * part of downgr8 by throwaway96
 * licensed under AGPL 3.0 or later
 * https://github.com/throwaway96/downgr8
 */

var pkgInfo = require("./package.json");
var serviceId = pkgInfo.name;

var Service = require("webos-service");
var service = new Service(serviceId, undefined, { idleTimer: 15 });

var child_process = require("child_process");

function isRoot() {
  var uid = process.getuid();
  console.log("uid: " + uid);
  return uid === 0;
}

var keepAlive;

/* stop service from being killed when idle */
service.activityManager.create("keepAlive", function (activity) {
  keepAlive = activity;
});

var subscriptions = {};

var getStatus = service.register("fakeusb/getStatus");

getStatus.on("request", function (message) {
  try {
    var sender = message.sender;
    console.log("got a fakeusb/getStatus request from " + sender);
  } catch (err) {
    var message = "message" in err ? err.message : "<no message>";
    console.warn(
      "something went wrong in fakeusb/getStatus request handler: " + message
    );
  }

  message.respond({
    returnValue: true,
    isAttached: true,
    isAuthenticated: true,
  });

  if (message.isSubscription) {
    subscriptions[message.uniqueToken] = message;
  }
});

getStatus.on("cancel", function (message) {
  try {
    var sender = message.sender;
    console.log("subscription to fakeusb/getStatus canceled by " + sender);
  } catch (err) {
    var message = "message" in err ? err.message : "<no message>";
    console.warn(
      "something went wrong in fakeusb/getStatus cancel handler: " + message
    );
  }

  delete subscriptions[message.uniqueToken];
});

/* TODO: avoid hardcoding this path */
var elevatePath =
  "/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service";

service.register("elevate", function (message) {
  if (isRoot()) {
    message.respond({ returnValue: true, errorText: "already root" });
    return;
  }

  var elevateCommand = elevatePath + " " + serviceId;

  service.call(
    "luna://org.webosbrew.hbchannel.service/exec",
    { command: elevateCommand },
    function (innerMessage) {
      var payload = innerMessage.payload;

      var result = "returnValue" in payload ? payload["returnValue"] : false;

      message.respond({ returnValue: result });

      if (result) {
        service.activityManager.complete(keepAlive);
        process.exit(0);
      }
    }
  );
});

function doPatchAsync(pid) {
  var pidArg = typeof pid === "number" ? "'" + pid + "'" : '"$(pidof update)"';

  var patchPath = __dirname + "/patch";
  var command = "'" + patchPath + "' " + pidArg;

  return new Promise(function (resolve, reject) {
    child_process.exec(command, function (error, stdout, stderr) {
      var exitStatus = error !== null ? error.code : 0;

      resolve({
        returnValue: exitStatus == 0,
        exitStatus: exitStatus,
        stdout: stdout,
        stderr: stderr,
      });
    });
  });
}

function doRestartAsync() {
  var command = "restart securitymanager";

  return new Promise(function (resolve, reject) {
    child_process.exec(command, function (error, stdout, stderr) {
      var exitStatus = error !== null ? error.code : 0;

      resolve({
        returnValue: exitStatus == 0,
        exitStatus: exitStatus,
        stdout: stdout,
        stderr: stderr,
      });
    });
  });
}

service.register("patch", function (message) {
  if (isRoot()) {
    doPatchAsync()
      .then(function (value) {
        message.respond(value);
      })
      .catch(function (err) {
        console.error(err);
        var errorText = "exception: " + err.message;
        message.respond({ returnValue: false, errorText: errorText });
      });
  } else {
    message.respond({ returnValue: false, errorText: "not root" });
  }
});

service.register("restart", function (message) {
  if (isRoot()) {
    doRestartAsync()
      .then(function (value) {
        message.respond(value);
      })
      .catch(function (err) {
        console.error(err);
        var errorText = "exception: " + err.message;
        message.respond({ returnValue: false, errorText: errorText });
      });
  } else {
    message.respond({ returnValue: false, errorText: "not root" });
  }
});

service.register("launchUpdate", function (message) {
  /* TODO: clean this up */
  service.call(
    "luna://com.webos.service.update/setExpertMode",
    { mode: true },
    function (response) {
      var payload = response.payload;
      var result = "returnValue" in payload ? payload["returnValue"] : false;

      if (!result) {
        message.respond({
          returnValue: false,
          errorText: "setExpertMode failed",
        });
        return;
      }

      service.call(
        "luna://com.webos.applicationManager/launch",
        {
          id: "com.webos.app.softwareupdate",
          params: { mode: "expert", flagUpdate: true },
        },
        function (innerResponse) {
          var payload = innerResponse.payload;
          var result =
            "returnValue" in payload ? payload["returnValue"] : false;

          if (result) {
            message.respond({ returnValue: true });
          } else {
            message.respond({ returnValue: false, errorText: "launch failed" });
          }
        }
      );
    }
  );
});
