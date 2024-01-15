#!/usr/bin/env node

/*
 * part of downgr8 by throwaway96
 * licensed under AGPL 3.0 or later
 * https://github.com/throwaway96/downgr8
 */

var pkgInfo = require("./package.json");
var Service = require("webos-service");
var service = new Service(pkgInfo.name);

var subscriptions = {};

var getStatus = service.register("fakeusb/getStatus");

getStatus.on("request", function (message) {
  console.log("got one");

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
  console.log("canceled");
  delete subscriptions[message.uniqueToken];
});
