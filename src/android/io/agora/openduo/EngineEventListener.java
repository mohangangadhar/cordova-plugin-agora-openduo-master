package io.openduo;


import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.agora.rtc.IRtcEngineEventHandler;
import io.agora.rtm.LocalInvitation;
import io.agora.rtm.RemoteInvitation;
import io.agora.rtm.RtmCallEventListener;
import io.agora.rtm.RtmClientListener;
import io.agora.rtm.RtmMessage;

public class EngineEventListener extends IRtcEngineEventHandler {
    private List<IEventListener> mListeners = new ArrayList<>();

    public void registerEventListener(IEventListener listener) {
        if (!mListeners.contains(listener)) {
            mListeners.add(listener);
        }
    }

    public void removeEventListener(IEventListener listener) {
        mListeners.remove(listener);
    }

    @Override
    public void onJoinChannelSuccess(String channel, int uid, int elapsed) {
        int size = mListeners.size();
        if (size > 0) {
            mListeners.get(size - 1).onJoinChannelSuccess(channel, uid, elapsed);
        }
    }

    @Override
    public void onUserJoined(int uid, int elapsed) {
        int size = mListeners.size();
        if (size > 0) {
            mListeners.get(size - 1).onUserJoined(uid, elapsed);
        }
    }

    @Override
    public void onUserOffline(int uid, int reason) {
        int size = mListeners.size();
        if (size > 0) {
            mListeners.get(size - 1).onUserOffline(uid, reason);
        }
    }

    @Override
    public void onConnectionStateChanged(int status, int reason) {
        int size = mListeners.size();
        if (size > 0) {
            mListeners.get(size - 1).onConnectionStateChanged(status, reason);
        }
    }

}

