package io.openduo.activity;

import android.Manifest;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.view.animation.AnimationSet;
import android.view.animation.ScaleAnimation;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.bumptech.glide.Glide;

import org.json.JSONException;
import org.json.JSONObject;

import de.hdodenhof.circleimageview.CircleImageView;
import io.agora.rtm.ErrorInfo;
import io.agora.rtm.LocalInvitation;
import io.agora.rtm.RemoteInvitation;
import io.agora.rtm.ResultCallback;
import io.openduo.AgoraEngine;
import io.openduo.Constants;
import io.openduo.FakeR;

public class CallActivity extends Activity implements ResultCallback<Void> {
    private FakeR fakeR;
    private int mRole;
    private String mPeer;
    private String mPeerData;
    private String mChannel;
    private ImageView mAcceptBtn;
    private ImageView mHangupBtn;
    private MediaPlayer mPlayer;
    private PortraitAnimator mAnimator;

    private String[] PERMISSIONS = {
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.CAMERA,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
    };

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            onBackPressed();
        }
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().requestFeature(Window.FEATURE_ACTION_BAR);
        getActionBar().hide();

        fakeR = new FakeR(this);
        setContentView(fakeR.getId("layout", "activity_call"));
        initUI();
        if (isCaller()) {
            sendInvitation();
        }
        startRinging();
    }

    @Override
    public void onStart() {
        super.onStart();
        //registerEventListener(this);
        mAnimator.start();
    }

    @Override
    public void onStop() {
        super.onStop();
        //removeEventListener(this);
        stopRinging();
        mAnimator.stop();
    }

    @Override
    protected void onPause() {
        super.onPause();
        unregisterReceiver(mMessageReceiver);
    }

    @Override
    protected void onResume() {
        super.onResume();
        registerReceiver(mMessageReceiver, new IntentFilter("io.openduo.KILL_ME"));
    }

    //    private void registerEventListener(IEventListener listener) {
//        AgoraEngine.getInstance().registerEventListener(listener);
//    }
//
//    private void removeEventListener(IEventListener listener) {
//        AgoraEngine.getInstance().removeEventListener(listener);
//    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        //removeEventListener(this);
    }

    private void initUI() {
        Intent intent = getIntent();
        mChannel = intent.getStringExtra(Constants.KEY_CALLING_CHANNEL);
        mPeer = intent.getStringExtra(Constants.KEY_CALLING_PEER);
        mPeerData = intent.getStringExtra(Constants.KEY_PEER_AD_DATA);

        mHangupBtn = findViewById(fakeR.getId("id", "hang_up_btn"));
        mHangupBtn.setVisibility(View.VISIBLE);
        mHangupBtn.setOnClickListener(v -> {
            if (isCaller()) {
                if (AgoraEngine.getInstance().getRtmCallManager() != null && AgoraEngine.getInstance().getLocalInvitation() != null) {
                    AgoraEngine.getInstance().getRtmCallManager().cancelLocalInvitation(AgoraEngine.getInstance().getLocalInvitation(), this);
                }
            } else if (isCallee()) {
                if (AgoraEngine.getInstance().getRtmCallManager() != null) {
                    AgoraEngine.getInstance().getRtmCallManager().refuseRemoteInvitation(AgoraEngine.getInstance().getRemoteInvitation(), this);
                }
            }
            onBackPressed();
        });

        TextView roleText = findViewById(fakeR.getId("id", "call_role"));
        mAcceptBtn = findViewById(fakeR.getId("id", "accept_call_btn"));


        mRole = intent.getIntExtra(Constants.KEY_CALLING_ROLE, Constants.ROLE_CALLEE);
        TextView peer_number_layout = findViewById(fakeR.getId("id", "peer_number_layout"));
        CircleImageView portrait = findViewById(fakeR.getId("id", "peer_image"));
        if (isCallee()) {
            roleText.setText("Incoming Call");
            mAcceptBtn.setVisibility(View.VISIBLE);
            mAcceptBtn.setOnClickListener(v -> {
                if (permissionArrayGranted(null)) {
                    answerCall(AgoraEngine.getInstance().getRemoteInvitation());
                } else {
                    ActivityCompat.requestPermissions(CallActivity.this, PERMISSIONS, 99);
                }
            });

            try {
                peer_number_layout.setText(new JSONObject(mPeerData).getString("name_caller"));
                Glide.with(this).load(new JSONObject(mPeerData).getString("image_caller")).placeholder(fakeR.getId("drawable", "empty_dp")).dontAnimate().into(portrait);
            } catch (JSONException e) {
                peer_number_layout.setText(mPeer);
                portrait.setImageResource(fakeR.getId("drawable", "portrait"));
            }
        } else if (isCaller()) {
            roleText.setText("Calling..");
            mAcceptBtn.setVisibility(View.GONE);

            try {
                peer_number_layout.setText(new JSONObject(mPeerData).getString("name_callee"));
                Glide.with(this).load(new JSONObject(mPeerData).getString("image_callee")).placeholder(fakeR.getId("drawable", "empty_dp")).dontAnimate().into(portrait);
            } catch (JSONException e) {
                peer_number_layout.setText(mPeer);
                portrait.setImageResource(fakeR.getId("drawable", "portrait"));
            }
        }

        mAnimator = new PortraitAnimator(
                findViewById(fakeR.getId("id", "anim_layer_1")),
                findViewById(fakeR.getId("id", "anim_layer_2")),
                findViewById(fakeR.getId("id", "anim_layer_3")));
    }

    private void sendInvitation() {
        LocalInvitation invitation = AgoraEngine.getInstance().getRtmCallManager().createLocalInvitation(mPeer);
        invitation.setChannelId(mChannel);
        invitation.setContent(mPeerData);
        AgoraEngine.getInstance().getRtmCallManager().sendLocalInvitation(invitation, this);
        AgoraEngine.getInstance().setLocalInvitation(invitation);
    }

    private void answerCall(final RemoteInvitation invitation) {
        if (AgoraEngine.getInstance().getRtmCallManager() != null && invitation != null) {
            AgoraEngine.getInstance().getRtmCallManager().acceptRemoteInvitation(invitation, this);
        }
    }

    private void startRinging() {
        if (isCallee()) {
            mPlayer = playCalleeRing();
        } else if (isCaller()) {
            mPlayer = playCallerRing();
        }
    }

    private MediaPlayer playCallerRing() {
        return startRinging(fakeR.getId("raw", "basic_ring"));
    }

    private MediaPlayer playCalleeRing() {
        return startRinging(fakeR.getId("raw", "basic_tones"));
    }

    private MediaPlayer startRinging(int resource) {
        MediaPlayer player = MediaPlayer.create(this, resource);
        player.setLooping(true);
        player.start();
        return player;
    }

    private void stopRinging() {
        if (mPlayer != null && mPlayer.isPlaying()) {
            mPlayer.stop();
            mPlayer.release();
            mPlayer = null;
        }
    }

    private boolean isCaller() {
        return mRole == Constants.ROLE_CALLER;
    }

    private boolean isCallee() {
        return mRole == Constants.ROLE_CALLEE;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (permissionArrayGranted(permissions))
            answerCall(AgoraEngine.getInstance().getRemoteInvitation());
        else
            onBackPressed();
    }

    @Override
    public void onSuccess(Void aVoid) {

    }

    @Override
    public void onFailure(ErrorInfo errorInfo) {
        Log.e("onFailure", errorInfo.getErrorCode() + ": " + errorInfo.getErrorDescription());
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
        return ContextCompat.checkSelfPermission(
                this, permission) == PackageManager.PERMISSION_GRANTED;
    }

    private class PortraitAnimator {
        static final int ANIM_DURATION = 3000;

        private Animation mAnim1;
        private Animation mAnim2;
        private Animation mAnim3;
        private View mLayer1;
        private View mLayer2;
        private View mLayer3;
        private boolean mIsRunning;

        PortraitAnimator(View layer1, View layer2, View layer3) {
            mLayer1 = layer1;
            mLayer2 = layer2;
            mLayer3 = layer3;
            mAnim1 = buildAnimation(0);
            mAnim2 = buildAnimation(1000);
            mAnim3 = buildAnimation(2000);
        }

        private AnimationSet buildAnimation(int startOffset) {
            AnimationSet set = new AnimationSet(true);
            AlphaAnimation alphaAnimation = new AlphaAnimation(1.0f, 0.0f);
            alphaAnimation.setDuration(ANIM_DURATION);
            alphaAnimation.setStartOffset(startOffset);
            alphaAnimation.setRepeatCount(Animation.INFINITE);
            alphaAnimation.setRepeatMode(Animation.RESTART);
            alphaAnimation.setFillAfter(true);

            ScaleAnimation scaleAnimation = new ScaleAnimation(
                    1.0f, 1.3f, 1.0f, 1.3f,
                    ScaleAnimation.RELATIVE_TO_SELF, 0.5f,
                    ScaleAnimation.RELATIVE_TO_SELF, 0.5f);
            scaleAnimation.setDuration(ANIM_DURATION);
            scaleAnimation.setStartOffset(startOffset);
            scaleAnimation.setRepeatCount(Animation.INFINITE);
            scaleAnimation.setRepeatMode(Animation.RESTART);
            scaleAnimation.setFillAfter(true);

            set.addAnimation(alphaAnimation);
            set.addAnimation(scaleAnimation);
            return set;
        }

        void start() {
            if (!mIsRunning) {
                mIsRunning = true;
                mLayer1.setVisibility(View.VISIBLE);
                mLayer2.setVisibility(View.VISIBLE);
                mLayer3.setVisibility(View.VISIBLE);
                mLayer1.startAnimation(mAnim1);
                mLayer2.startAnimation(mAnim2);
                mLayer3.startAnimation(mAnim3);
            }
        }

        void stop() {
            mLayer1.clearAnimation();
            mLayer2.clearAnimation();
            mLayer3.clearAnimation();
            mLayer1.setVisibility(View.GONE);
            mLayer2.setVisibility(View.GONE);
            mLayer3.setVisibility(View.GONE);
        }
    }

}
