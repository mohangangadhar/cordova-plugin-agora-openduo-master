package io.openduo;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import org.apache.cordova.CallbackContext;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import io.agora.rtc.Constants;
import io.agora.rtc.RtcEngine;
import io.agora.rtm.ErrorInfo;
import io.agora.rtm.LocalInvitation;
import io.agora.rtm.RemoteInvitation;
import io.agora.rtm.ResultCallback;
import io.agora.rtm.RtmCallEventListener;
import io.agora.rtm.RtmCallManager;
import io.agora.rtm.RtmClient;
import io.agora.rtm.RtmClientListener;
import io.agora.rtm.RtmMessage;
import io.openduo.activity.CallActivity;
import io.openduo.activity.VideoActivity;

public class AgoraEngine {
    private String appId;
    private String token = null;
    private Context applicationContext;
    private RtcEngine rtcEngine = null;
    private RtmClient mRtmClient;
    private RtmCallManager rtmCallManager;

    private EngineEventListener mEventListener;
    private Activity mActivity;

    private LocalInvitation mLocalInvitation;
    private RemoteInvitation mRemoteInvitation;
    private String myId, mAccessToken;

    public String getMyId() {
        return myId;
    }

    public String getAccessToken() {
        return mAccessToken;
    }

    public LocalInvitation getLocalInvitation() {
        return mLocalInvitation;
    }

    public RemoteInvitation getRemoteInvitation() {
        return mRemoteInvitation;
    }

    public void setLocalInvitation(LocalInvitation li) {
        this.mLocalInvitation = li;
    }

    public void registerEventListener(IEventListener listener) {
        mEventListener.registerEventListener(listener);
    }

    public void removeEventListener(IEventListener listener) {
        mEventListener.removeEventListener(listener);
    }

    public AgoraEngine() {
    }

    public RtmCallManager getRtmCallManager() {
        return rtmCallManager;
    }

    public Context getApplicationContext() {
        return applicationContext;
    }

    public void setApplicationContext(Context applicationContext, Activity activity) {
        this.applicationContext = applicationContext;
        this.mActivity = activity;
    }

    public void unMuteLocalStream() {
        if (this.rtcEngine != null) {
            this.rtcEngine.muteLocalAudioStream(false);
            this.rtcEngine.muteLocalVideoStream(false);
        }
    }

    public void setAppId(String appId, CallbackContext callbackContext) {
        if (!appId.equals(this.appId)) {
            this.appId = appId;
            if (this.rtcEngine != null) {
                this.destroyRtcEngine();
            }
            mEventListener = new EngineEventListener();

            if (rtcEngine == null) {
                try {
                    rtcEngine = RtcEngine.create(getApplicationContext(), appId, mEventListener);
                    rtcEngine.setChannelProfile(Constants.CHANNEL_PROFILE_LIVE_BROADCASTING);
                    rtcEngine.enableDualStreamMode(true);
                    rtcEngine.enableVideo();

                    mRtmClient = RtmClient.createInstance(getApplicationContext(), appId, new RtmClientListener() {
                        @Override
                        public void onConnectionStateChanged(int i, int i1) {
                            Log.d("ConnectionStateChanged", "onConnectionStateChanged: " + i + " and " + i1);
                        }

                        @Override
                        public void onMessageReceived(RtmMessage rtmMessage, String s) {
                            Log.d("MessageReceived", "rtmMessage: " + rtmMessage.toString() + " and " + s);
                        }

                        @Override
                        public void onTokenExpired() {
                            Log.d("TokenExpired", "rtm TokenExpired");
                        }

                        @Override
                        public void onPeersOnlineStatusChanged(Map<String, Integer> map) {
                            Log.d("OnlineStatusChanged", map.toString());
                        }
                    });

                    rtmCallManager = mRtmClient.getRtmCallManager();
                    rtmCallManager.setEventListener(new RtmCallEventListener() {
                        @Override
                        public void onLocalInvitationReceivedByPeer(LocalInvitation localInvitation) {
                            Log.d("LocalIntnRcvdByPeer", localInvitation.getContent());
                        }

                        @Override
                        public void onLocalInvitationAccepted(LocalInvitation localInvitation, String s) {
                            Log.d("LocalIntnAccepted", localInvitation.getCalleeId() + " -:- " + localInvitation.getChannelId() + ": " + s);

                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                            mActivity.runOnUiThread(() -> {
                                Intent intent = new Intent(mActivity, VideoActivity.class);
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_CHANNEL, localInvitation.getChannelId());
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_PEER, localInvitation.getCalleeId());
                                intent.putExtra(io.openduo.Constants.KEY_PEER_AD_DATA, localInvitation.getContent());
                                mActivity.startActivity(intent);
                            });
                        }

                        @Override
                        public void onLocalInvitationRefused(LocalInvitation localInvitation, String s) {
                            Log.d("LocalIntnRfsd", localInvitation.getContent() + ": " + s);
                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                        }

                        @Override
                        public void onLocalInvitationCanceled(LocalInvitation localInvitation) {
                            Log.d("LocalIntnCncld", localInvitation.getContent());
                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                        }

                        @Override
                        public void onLocalInvitationFailure(LocalInvitation localInvitation, int i) {
                            Log.d("LocalIntnFailed", localInvitation.getResponse() + ": " + i);
                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                        }

                        @Override
                        public void onRemoteInvitationReceived(RemoteInvitation remoteInvitation) {
                            Log.d("RemoteIntnRcvd", remoteInvitation.getContent());

                            mRemoteInvitation = remoteInvitation;
                            mActivity.runOnUiThread(() -> {
                                Intent intent = new Intent(mActivity, CallActivity.class);
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_CHANNEL, mRemoteInvitation.getChannelId());
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_PEER, mRemoteInvitation.getCallerId());
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_ROLE, io.openduo.Constants.ROLE_CALLEE);
                                intent.putExtra(io.openduo.Constants.KEY_PEER_AD_DATA, mRemoteInvitation.getContent());
                                mActivity.startActivity(intent);
                            });
                        }

                        @Override
                        public void onRemoteInvitationAccepted(RemoteInvitation remoteInvitation) {
                            Log.d("RemoteIntnAccepted", remoteInvitation.getCallerId() + " -:- " + remoteInvitation.getChannelId());

                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));

                            mActivity.runOnUiThread(() -> {
                                Intent intent = new Intent(mActivity, VideoActivity.class);
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_CHANNEL, remoteInvitation.getChannelId());
                                intent.putExtra(io.openduo.Constants.KEY_CALLING_PEER, remoteInvitation.getCallerId());
                                intent.putExtra(io.openduo.Constants.KEY_PEER_AD_DATA, remoteInvitation.getContent());
                                mActivity.startActivity(intent);
                            });
                        }

                        @Override
                        public void onRemoteInvitationRefused(RemoteInvitation remoteInvitation) {
                            Log.d("RemoteIntnRfsd", remoteInvitation.getContent());
                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                        }

                        @Override
                        public void onRemoteInvitationCanceled(RemoteInvitation remoteInvitation) {
                            Log.d("RemoteIntnCncld", remoteInvitation.getContent());
                            applicationContext.sendBroadcast(new Intent("io.openduo.KILL_ME"));
                        }

                        @Override
                        public void onRemoteInvitationFailure(RemoteInvitation remoteInvitation, int i) {
                            Log.d("RemoteIntnFail", remoteInvitation.getContent() + ": " + i);
                        }
                    });

                    callbackContext.success("initialised");
                } catch (Exception e) {
                    e.printStackTrace();
                    callbackContext.error(e.getMessage());
                }
            } else {
                callbackContext.success("already initialised rtc");
            }
        } else {
            callbackContext.success("already initialised");
        }
    }

    public void checkAndJoinChannel(String peerId, String channelName, String additionalData, CallbackContext callbackContext) {
        Set<String> peerSet = new HashSet<>();
        peerSet.add(peerId);

        mRtmClient.queryPeersOnlineStatus(peerSet, new ResultCallback<Map<String, Boolean>>() {
            @Override
            public void onSuccess(Map<String, Boolean> statusMap) {
                Boolean bOnline = statusMap.get(peerId);
                if (bOnline != null && bOnline) {
                    mActivity.runOnUiThread(() -> {
                        Intent intent = new Intent(mActivity, CallActivity.class);
                        intent.putExtra(io.openduo.Constants.KEY_CALLING_CHANNEL, channelName);
                        intent.putExtra(io.openduo.Constants.KEY_CALLING_PEER, peerId);
                        intent.putExtra(io.openduo.Constants.KEY_CALLING_ROLE, io.openduo.Constants.ROLE_CALLER);
                        intent.putExtra(io.openduo.Constants.KEY_PEER_AD_DATA, additionalData);
                        mActivity.startActivity(intent);
                    });
                    if (callbackContext != null) callbackContext.success();
                } else {
                    if (callbackContext != null) callbackContext.error("peer_offline");
                }
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                if (callbackContext != null)
                    callbackContext.error(errorInfo.getErrorDescription());
            }
        });
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public void login(String accessToken, String userId, CallbackContext callbackContext) {
        this.myId = userId;
        this.mAccessToken = accessToken;
        mRtmClient.login(accessToken, userId, new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void aVoid) {
                if (callbackContext != null) callbackContext.success();
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                if (callbackContext != null)
                    callbackContext.error(errorInfo.getErrorDescription());
            }
        });
    }

    public void logout(CallbackContext callbackContext) {
        mRtmClient.logout(new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void aVoid) {
                if (callbackContext != null) callbackContext.success();
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                if (callbackContext != null)
                    callbackContext.error(errorInfo.getErrorDescription());
            }
        });
    }


    public void destroyRtcEngine() {
        if (rtcEngine != null) {
            try {
                RtcEngine.destroy();
                rtcEngine = null;
                logout(null);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public RtcEngine getRtcEngine() {
        return rtcEngine;
    }


    private static final AgoraEngine holder = new AgoraEngine();

    public static AgoraEngine getInstance() {
        return holder;
    }
}
