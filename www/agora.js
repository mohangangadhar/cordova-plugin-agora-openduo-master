
var exec = require('cordova/exec'),
    cordova = require('cordova'),
    channel = require('cordova/channel'),
    utils = require('cordova/utils');



/**
 * Node.js ���¼���
 *
 * @external EventEmitter
 * @see {@link https://nodejs.org/api/events.html}
 */

var self = this;
this.vendorKey = "";
this.logAllEvents = false;

this.callbackfunc = null;


channel.onCordovaReady.subscribe(function () {

    cordova.exec(function (event) {

        if (event !== 0) {

            event = JSON.parse(event);
            if (self.logAllEvents)
                console.info("CordovaAgora." + event.eventName, JSON.parse(event.data));

            // window.dispatchEvent("CordovaAgora", event);
            // alert(event.data)
            if (self.callbackfunc) {

                self.callbackfunc(event)
            }
        }

    }, function () {

        console.error("CordovaAgora: Failed to listen for events.");
    }, 'Agora', 'listenForEvents', []);
});

module.exports = {
    initAgora: function (vendorKey, successCallback, failCallback) {
        cordova.exec(successCallback, failCallback, 'Agora', 'initAgora', [vendorKey]);
        self.vendorKey = vendorKey;
    },
    startLoggingAllEvents: function () {
        self.logAllEvents = true;
    },
    stopLoggingAllEvents: function () {
        self.logAllEvents = false;
    },
    setCallBack: function (callbackfunc) {
        self.callbackfunc = callbackfunc
    },
    loginUser: function (accessToken, userId, successCallback, failCallback) {
        if (!self.vendorKey) {
            if (typeof failCallback == 'function') {
                failCallback('call initAgora() first!');
            }
        }
        cordova.exec(successCallback, failCallback, 'Agora', 'loginUser', [accessToken, userId]);
    },
    callUser: function (peerId, channelName, additionalData, successCallback, failCallback) {
        if (!self.vendorKey) {
            if (typeof failCallback == 'function') {
                failCallback('call initAgora() first!');
            }
        }
        cordova.exec(successCallback, failCallback, 'Agora', 'callUser', [peerId, channelName, additionalData]);
    },
    logout: function (successCallback, failCallback) {
        cordova.exec(successCallback, failCallback, 'Agora', 'logout', []);
    }
};





