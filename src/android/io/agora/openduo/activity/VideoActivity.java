package io.openduo.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.SurfaceView;
import android.view.View;
import android.view.Window;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.Toast;

import java.util.Map;

import io.agora.rtc.RtcEngine;
import io.agora.rtc.video.VideoCanvas;
import io.agora.rtc.video.VideoEncoderConfiguration;
import io.agora.rtm.LocalInvitation;
import io.agora.rtm.RemoteInvitation;
import io.openduo.AgoraEngine;
import io.openduo.Constants;
import io.openduo.FakeR;
import io.openduo.IEventListener;

public class VideoActivity extends Activity implements IEventListener {
    private FakeR fakeR;

    private FrameLayout mLocalPreviewLayout;
    private FrameLayout mRemotePreviewLayout;
    private ImageView mMuteBtn;
    private String mChannel, mPeerId, mPeerData;

    private VideoEncoderConfiguration.VideoDimensions mVideoDimension =
            VideoEncoderConfiguration.VD_640x480;

    private VideoEncoderConfiguration.FRAME_RATE mFrameRate =
            VideoEncoderConfiguration.FRAME_RATE.FRAME_RATE_FPS_15;

    private VideoEncoderConfiguration.ORIENTATION_MODE mOrientation =
            VideoEncoderConfiguration.ORIENTATION_MODE.ORIENTATION_MODE_FIXED_PORTRAIT;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().requestFeature(Window.FEATURE_ACTION_BAR);
        getActionBar().hide();

        fakeR = new FakeR(this);
        setContentView(fakeR.getId("layout", "activity_video"));

        initUI();
        initVideo();
    }

    @Override
    public void onStart() {
        super.onStart();
        AgoraEngine.getInstance().registerEventListener(this);
    }

    @Override
    public void onStop() {
        super.onStop();
        AgoraEngine.getInstance().removeEventListener(this);
    }

    private void initUI() {
        mLocalPreviewLayout = findViewById(fakeR.getId("id", "local_preview_layout"));
        mRemotePreviewLayout = findViewById(fakeR.getId("id", "remote_preview_layout"));

        mMuteBtn = findViewById(fakeR.getId("id", "btn_mute"));
        mMuteBtn.setActivated(true);

        findViewById(fakeR.getId("id", "btn_endcall")).setOnClickListener(v -> finish());
        findViewById(fakeR.getId("id", "btn_switch_camera")).setOnClickListener(v -> AgoraEngine.getInstance().getRtcEngine().switchCamera());
        findViewById(fakeR.getId("id", "btn_mute")).setOnClickListener(v -> {
            AgoraEngine.getInstance().getRtcEngine().muteLocalAudioStream(mMuteBtn.isActivated());
            mMuteBtn.setActivated(!mMuteBtn.isActivated());
        });

    }

    private void initVideo() {
        Intent intent = getIntent();
        mChannel = intent.getStringExtra(Constants.KEY_CALLING_CHANNEL);
        mPeerId = intent.getStringExtra(Constants.KEY_CALLING_PEER);
        mPeerData = intent.getStringExtra(Constants.KEY_PEER_AD_DATA);

        AgoraEngine.getInstance().getRtcEngine().setClientRole(io.agora.rtc.Constants.CLIENT_ROLE_BROADCASTER);
        setVideoConfiguration();
        setupLocalPreview();
        joinRtcChannel(mChannel, "", Integer.parseInt(AgoraEngine.getInstance().getMyId()));
    }

    @Override
    public void onJoinChannelSuccess(String channel, int uid, int elapsed) {

    }

    @Override
    public void onUserJoined(final int uid, int elapsed) {
        if (uid != Integer.parseInt(mPeerId)) return;
        runOnUiThread(() -> {
            if (mRemotePreviewLayout.getChildCount() == 0) {
                SurfaceView surfaceView = setupVideo(uid, false);
                mRemotePreviewLayout.addView(surfaceView);
            }
        });
    }

    @Override
    public void onUserOffline(int uid, int reason) {
        if (uid != Integer.parseInt(mPeerId)) return;
        finish();
    }

    @Override
    public void onConnectionStateChanged(int status, int reason) {

    }

    @Override
    public void onPeersOnlineStatusChanged(Map<String, Integer> map) {

    }

    @Override
    public void onLocalInvitationReceived(LocalInvitation localInvitation) {

    }

    @Override
    public void onLocalInvitationAccepted(LocalInvitation localInvitation, String response) {

    }

    @Override
    public void onLocalInvitationRefused(LocalInvitation localInvitation, String response) {

    }

    @Override
    public void onLocalInvitationCanceled(LocalInvitation localInvitation) {

    }

    @Override
    public void onLocalInvitationFailure(LocalInvitation localInvitation, int errorCode) {

    }

    @Override
    public void onRemoteInvitationReceived(RemoteInvitation remoteInvitation) {

    }

    @Override
    public void onRemoteInvitationAccepted(RemoteInvitation remoteInvitation) {

    }

    @Override
    public void onRemoteInvitationRefused(RemoteInvitation remoteInvitation) {

    }

    @Override
    public void onRemoteInvitationCanceled(RemoteInvitation remoteInvitation) {

    }

    @Override
    public void onRemoteInvitationFailure(RemoteInvitation remoteInvitation, int errorCode) {

    }

    @Override
    public void onLocalInvitationReceivedByPeer(LocalInvitation localInvitation) {

    }

    @Override
    public void finish() {
        super.finish();
        AgoraEngine.getInstance().getRtcEngine().leaveChannel();
    }

    private void joinRtcChannel(String channel, String info, int uid) {
        AgoraEngine.getInstance().getRtcEngine().joinChannel(AgoraEngine.getInstance().getAccessToken(), channel, info, uid);
    }

    private SurfaceView setupVideo(int uid, boolean local) {
        SurfaceView surfaceView = RtcEngine.
                CreateRendererView(getApplicationContext());
        if (local) {
            AgoraEngine.getInstance().getRtcEngine().setupLocalVideo(new VideoCanvas(surfaceView,
                    VideoCanvas.RENDER_MODE_HIDDEN, uid));
        } else {
            AgoraEngine.getInstance().getRtcEngine().setupRemoteVideo(new VideoCanvas(surfaceView,
                    VideoCanvas.RENDER_MODE_HIDDEN, uid));
        }

        return surfaceView;
    }

    private void setupLocalPreview() {
        SurfaceView surfaceView = setupVideo(Integer.parseInt(AgoraEngine.getInstance().getMyId()), true);
        surfaceView.setZOrderOnTop(true);
        mLocalPreviewLayout.addView(surfaceView);
    }

    private void setVideoConfiguration() {
        AgoraEngine.getInstance().getRtcEngine().setVideoEncoderConfiguration(
                new VideoEncoderConfiguration(
                        mVideoDimension,
                        mFrameRate,
                        VideoEncoderConfiguration.STANDARD_BITRATE,
                        mOrientation)
        );
    }
}
