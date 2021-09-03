package io.openduo;


import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceView;

import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONStringer;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import io.openduo.activity.CallActivity;


public class Agora extends CordovaPlugin {
    public static final String TAG = "CDVAgora";
    protected Activity appActivity;
    protected Context appContext;

    private String accessToken, userId;
    private PlaceCallData placeCallData;

    private String[] PERMISSIONS = {
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.CAMERA,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
    };

//    @Override
//    public void onDestroy() {
//        super.onDestroy();
//        AgoraEngine.getInstance().destroyRtcEngine();
//    }

    @Override
    protected void pluginInitialize() {
        appContext = this.cordova.getActivity().getApplicationContext();
        appActivity = cordova.getActivity();
        super.pluginInitialize();
        AgoraEngine.getInstance().setApplicationContext(appContext, appActivity);
    }

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        Log.d(TAG, action + " called");

        switch (action) {
            case "initAgora":
                String appId = args.getString(0);
                AgoraEngine.getInstance().setAppId(appId, callbackContext);
                return true;
            case "loginUser":
                accessToken = args.getString(0);
                if (accessToken != null && accessToken.equals("null")) accessToken = null;
                userId = args.getString(1);
                AgoraEngine.getInstance().login(accessToken, userId, callbackContext);
                return true;
            case "callUser":
                placeCallData = null;
                if (permissionArrayGranted(null)) {
                    String peerId = args.getString(0);
                    String channelName = args.getString(1);
                    String additionalData = args.getString(2);
                    AgoraEngine.getInstance().checkAndJoinChannel(peerId, channelName, additionalData, callbackContext);
                } else {
                    callbackContext.error("no_permission");
                    placeCallData = new PlaceCallData(args.getString(0), args.getString(1), args.getString(2));
                    cordova.requestPermissions(this, 89, PERMISSIONS);
                }
                return true;
            case "logout":
                if (userId != null) AgoraEngine.getInstance().logout(callbackContext);
                return true;
            default:
                return super.execute(action, args, callbackContext);
        }
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        super.onRequestPermissionResult(requestCode, permissions, grantResults);
        if (permissionArrayGranted(permissions) && requestCode == 89 && placeCallData != null) {
            AgoraEngine.getInstance().checkAndJoinChannel(placeCallData.getId(), placeCallData.getChannel(), placeCallData.getMeta(), null);
        }
    }

    private boolean permissionArrayGranted(@Nullable String[] permissions) {
        String[] permissionArray = permissions;
        if (permissionArray == null) {
            permissionArray = PERMISSIONS;
        }

        boolean granted = true;
        for (String per : permissionArray) {
            if (!permissionGranted(per)) {
                granted = false;
                break;
            }
        }
        return granted;
    }

    private boolean permissionGranted(String permission) {
        return cordova.hasPermission(permission);
    }


    public static String getToken(String appId, String certificate, String account, long expiredTsInSeconds) throws NoSuchAlgorithmException {
        StringBuilder digest_String = new StringBuilder().append(account).append(appId).append(certificate).append(expiredTsInSeconds);
        MessageDigest md5 = MessageDigest.getInstance("MD5");
        md5.update(digest_String.toString().getBytes());
        byte[] output = md5.digest();
        String token = hexlify(output);
        String token_String = new StringBuilder().append("1").append(":").append(appId).append(":").append(expiredTsInSeconds).append(":").append(token).toString();
        return token_String;
    }

    public static String hexlify(byte[] data) {

        char[] DIGITS_LOWER = {'0', '1', '2', '3', '4', '5',
                '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
        char[] toDigits = DIGITS_LOWER;
        int l = data.length;
        char[] out = new char[l << 1];
        // two characters form the hex value.
        for (int i = 0, j = 0; i < l; i++) {
            out[j++] = toDigits[(0xF0 & data[i]) >>> 4];
            out[j++] = toDigits[0x0F & data[i]];
        }
        return String.valueOf(out);
    }

    private class PlaceCallData {
        private String id, channel, meta;

        public PlaceCallData(String id, String channel, String meta) {
            this.id = id;
            this.channel = channel;
            this.meta = meta;
        }

        public String getId() {
            return id;
        }

        public String getChannel() {
            return channel;
        }

        public String getMeta() {
            return meta;
        }
    }


}
