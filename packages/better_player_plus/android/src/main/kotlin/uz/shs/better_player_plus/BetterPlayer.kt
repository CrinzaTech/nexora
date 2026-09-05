package uz.shs.better_player_plus

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import uz.shs.better_player_plus.DataSourceUtils.getUserAgent
import uz.shs.better_player_plus.DataSourceUtils.isHTTP
import uz.shs.better_player_plus.DataSourceUtils.getDataSourceFactory
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry.SurfaceTextureEntry
import io.flutter.plugin.common.MethodChannel
import androidx.media3.ui.PlayerNotificationManager
import androidx.work.WorkManager
import androidx.work.WorkInfo
import androidx.media3.ui.PlayerNotificationManager.MediaDescriptionAdapter
import androidx.media3.ui.PlayerNotificationManager.BitmapCallback
import androidx.work.OneTimeWorkRequest
import android.util.Log
import android.view.Surface
import androidx.annotation.RequiresApi
import androidx.lifecycle.Observer
import androidx.media3.extractor.DefaultExtractorsFactory
import io.flutter.plugin.common.EventChannel.EventSink
import androidx.work.Data
import androidx.media3.*
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.dash.DefaultDashChunkSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.drm.DummyExoMediaDrm
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.drm.UnsupportedDrmException
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.smoothstreaming.DefaultSsChunkSource
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource
import androidx.media3.exoplayer.source.ClippingMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import java.io.File
import java.lang.Exception
import java.lang.IllegalStateException
import java.util.*
import kotlin.math.max
import kotlin.math.min

internal class BetterPlayer(
    context: Context,
    private val eventChannel: EventChannel,
    private val textureEntry: SurfaceTextureEntry,
    customDefaultLoadControl: CustomDefaultLoadControl?,
    result: MethodChannel.Result
) {
    private val exoPlayer: ExoPlayer?
    private val eventSink = QueuingEventSink()
    private val trackSelector: DefaultTrackSelector = DefaultTrackSelector(context)
    private val loadControl: LoadControl
    private var isInitialized = false
    private var surface: Surface? = null
    private var key: String? = null
    private var playerNotificationManager: PlayerNotificationManager? = null
    private var refreshHandler: Handler? = null
    private var refreshRunnable: Runnable? = null
    private var exoPlayerEventListener: Player.Listener? = null
    private var bitmap: Bitmap? = null
    private var mediaSession: MediaSessionCompat? = null
    private var drmSessionManager: DrmSessionManager? = null
    private val workManager: WorkManager
    private val workerObserverMap: HashMap<UUID, Observer<WorkInfo?>>
    private val customDefaultLoadControl: CustomDefaultLoadControl =
        customDefaultLoadControl ?: CustomDefaultLoadControl()
    private var lastSendBufferedPosition = 0L

    init {
        val loadBuilder = DefaultLoadControl.Builder()
        loadBuilder.setBufferDurationsMs(
            this.customDefaultLoadControl.minBufferMs,
            this.customDefaultLoadControl.maxBufferMs,
            this.customDefaultLoadControl.bufferForPlaybackMs,
            this.customDefaultLoadControl.bufferForPlaybackAfterRebufferMs
        )
        loadControl = loadBuilder.build()
        exoPlayer = ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()
        workManager = WorkManager.getInstance(context)
        workerObserverMap = HashMap()
        setupVideoPlayer(eventChannel, textureEntry, result)
    }

    fun setDataSource(
        context: Context,
        key: String?,
        dataSource: String?,
        formatHint: String?,
        result: MethodChannel.Result,
        headers: Map<String, String>?,
        useCache: Boolean,
        maxCacheSize: Long,
        maxCacheFileSize: Long,
        overriddenDuration: Long,
        licenseUrl: String?,
        drmHeaders: Map<String, String>?,
        cacheKey: String?,
        clearKey: String?,
        liveTargetOffsetMs: Long = 0
    ) {
        this.key = key
        isInitialized = false
        val uri = Uri.parse(dataSource)
        var dataSourceFactory: DataSource.Factory?
        val userAgent = getUserAgent(headers)
        if (!licenseUrl.isNullOrEmpty()) {
            val httpMediaDrmCallback =
                HttpMediaDrmCallback(licenseUrl, DefaultHttpDataSource.Factory())
            if (drmHeaders != null) {
                for ((drmKey, drmValue) in drmHeaders) {
                    httpMediaDrmCallback.setKeyRequestProperty(drmKey, drmValue)
                }
            }
            if (Util.SDK_INT < 18) {
                Log.e(TAG, "Protected content not supported on API levels below 18")
                drmSessionManager = null
            } else {
                val drmSchemeUuid = Util.getDrmUuid("widevine")
                if (drmSchemeUuid != null) {
                    drmSessionManager = DefaultDrmSessionManager.Builder()
                        .setUuidAndExoMediaDrmProvider(
                            drmSchemeUuid
                        ) { uuid: UUID? ->
                            try {
                                val mediaDrm = FrameworkMediaDrm.newInstance(uuid!!)
                                // Force L3.
                                mediaDrm.setPropertyString("securityLevel", "L3")
                                return@setUuidAndExoMediaDrmProvider mediaDrm
                            } catch (e: UnsupportedDrmException) {
                                return@setUuidAndExoMediaDrmProvider DummyExoMediaDrm()
                            }
                        }
                        .setMultiSession(false)
                        .build(httpMediaDrmCallback)
                }
            }
        } else if (!clearKey.isNullOrEmpty()) {
            drmSessionManager = if (Util.SDK_INT < 18) {
                Log.e(TAG, "Protected content not supported on API levels below 18")
                null
            } else {
                DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(
                        C.CLEARKEY_UUID,
                        FrameworkMediaDrm.DEFAULT_PROVIDER
                    ).build(LocalMediaDrmCallback(clearKey.toByteArray()))
            }
        } else {
            drmSessionManager = null
        }
        if (isHTTP(uri)) {
            dataSourceFactory = getDataSourceFactory(userAgent, headers)
            if (useCache && maxCacheSize > 0 && maxCacheFileSize > 0) {
                dataSourceFactory = CacheDataSourceFactory(
                    context,
                    maxCacheSize,
                    maxCacheFileSize,
                    dataSourceFactory
                )
            }
        } else {
            dataSourceFactory = DefaultDataSource.Factory(context)
        }
        val mediaSource =
            buildMediaSource(uri, dataSourceFactory, formatHint, cacheKey, context, liveTargetOffsetMs)
        if (overriddenDuration != 0L) {
            val clippingMediaSource = ClippingMediaSource(mediaSource, 0, overriddenDuration * 1000)
            exoPlayer?.setMediaSource(clippingMediaSource)
        } else {
            exoPlayer?.setMediaSource(mediaSource)
        }
        exoPlayer?.prepare()
        result.success(null)
    }

    fun setupPlayerNotification(
        context: Context, title: String, author: String?,
        imageUrl: String?, notificationChannelName: String?,
        activityName: String
    ) {
        val mediaDescriptionAdapter: MediaDescriptionAdapter = object : MediaDescriptionAdapter {
            override fun getCurrentContentTitle(player: Player): String {
                return title
            }

            @RequiresApi(Build.VERSION_CODES.M)
            @SuppressLint("UnspecifiedImmutableFlag")
            override fun createCurrentContentIntent(player: Player): PendingIntent? {
                val packageName = context.applicationContext.packageName
                val notificationIntent = Intent()
                notificationIntent.setClassName(
                    packageName,
                    "$packageName.$activityName"
                )
                notificationIntent.flags = (Intent.FLAG_ACTIVITY_CLEAR_TOP
                        or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                return PendingIntent.getActivity(
                    context, 0,
                    notificationIntent,
                    PendingIntent.FLAG_IMMUTABLE
                )
            }

            override fun getCurrentContentText(player: Player): String? {
                return author
            }

            override fun getCurrentLargeIcon(
                player: Player,
                callback: BitmapCallback
            ): Bitmap? {
                if (imageUrl == null) {
                    return null
                }
                if (bitmap != null) {
                    return bitmap
                }
                val imageWorkRequest = OneTimeWorkRequest.Builder(ImageWorker::class.java)
                    .addTag(imageUrl)
                    .setInputData(
                        Data.Builder()
                            .putString(BetterPlayerPlugin.URL_PARAMETER, imageUrl)
                            .build()
                    )
                    .build()
                workManager.enqueue(imageWorkRequest)
                val workInfoObserver = Observer { workInfo: WorkInfo? ->
                    try {
                        if (workInfo != null) {
                            val state = workInfo.state
                            if (state == WorkInfo.State.SUCCEEDED) {
                                val outputData = workInfo.outputData
                                val filePath =
                                    outputData.getString(BetterPlayerPlugin.FILE_PATH_PARAMETER)
                                //Bitmap here is already processed and it's very small, so it won't
                                //break anything.
                                bitmap = BitmapFactory.decodeFile(filePath)
                                bitmap?.let { bitmap ->
                                    callback.onBitmap(bitmap)
                                }
                            }
                            if (state == WorkInfo.State.SUCCEEDED || state == WorkInfo.State.CANCELLED || state == WorkInfo.State.FAILED) {
                                val uuid = imageWorkRequest.id
                                val observer = workerObserverMap.remove(uuid)
                                if (observer != null) {
                                    workManager.getWorkInfoByIdLiveData(uuid)
                                        .removeObserver(observer)
                                }
                            }
                        }
                    } catch (exception: Exception) {
                        Log.e(TAG, "Image select error: $exception")
                    }
                }
                val workerUuid = imageWorkRequest.id
                workManager.getWorkInfoByIdLiveData(workerUuid)
                    .observeForever(workInfoObserver)
                workerObserverMap[workerUuid] = workInfoObserver
                return null
            }
        }
        var playerNotificationChannelName = notificationChannelName
        if (notificationChannelName == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val importance = NotificationManager.IMPORTANCE_LOW
                val channel = NotificationChannel(
                    DEFAULT_NOTIFICATION_CHANNEL,
                    DEFAULT_NOTIFICATION_CHANNEL, importance
                )
                channel.description = DEFAULT_NOTIFICATION_CHANNEL
                val notificationManager = context.getSystemService(
                    NotificationManager::class.java
                )
                notificationManager.createNotificationChannel(channel)
                playerNotificationChannelName = DEFAULT_NOTIFICATION_CHANNEL
            }
        }

        playerNotificationManager = PlayerNotificationManager.Builder(
            context, NOTIFICATION_ID,
            playerNotificationChannelName!!
        ).setMediaDescriptionAdapter(mediaDescriptionAdapter).build()

        playerNotificationManager?.apply {

            exoPlayer?.let {
                setPlayer(ForwardingPlayer(exoPlayer))
                setUseNextAction(false)
                setUsePreviousAction(false)
                setUseStopAction(false)
            }

            setupMediaSession(context)?.let {
                setMediaSessionToken(it.sessionToken)
            }
        }

        refreshHandler = Handler(Looper.getMainLooper())
        refreshRunnable = Runnable {
            val playbackState: PlaybackStateCompat = if (exoPlayer?.isPlaying == true) {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PLAYING, position, 1.0f)
                    .build()
            } else {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PAUSED, position, 1.0f)
                    .build()
            }
            mediaSession?.setPlaybackState(playbackState)
            refreshHandler?.postDelayed(refreshRunnable!!, 1000)
        }
        refreshHandler?.postDelayed(refreshRunnable!!, 0)
        exoPlayerEventListener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                mediaSession?.setMetadata(
                    MediaMetadataCompat.Builder()
                        .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, getDuration())
                        .build()
                )
            }
        }
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.addListener(exoPlayerEventListener)
        }
        exoPlayer?.seekTo(0)
    }

    fun disposeRemoteNotifications() {
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.removeListener(exoPlayerEventListener)
        }
        if (refreshHandler != null) {
            refreshHandler?.removeCallbacksAndMessages(null)
            refreshHandler = null
            refreshRunnable = null
        }
        if (playerNotificationManager != null) {
            playerNotificationManager?.setPlayer(null)
        }
        bitmap = null
    }

    private fun buildMediaSource(
        uri: Uri,
        mediaDataSourceFactory: DataSource.Factory,
        formatHint: String?,
        cacheKey: String?,
        context: Context,
        liveTargetOffsetMs: Long = 0
    ): MediaSource {
        val type: Int
        if (formatHint == null) {
            var lastPathSegment = uri.lastPathSegment
            if (lastPathSegment == null) {
                lastPathSegment = ""
            }
            type = Util.inferContentTypeForExtension(lastPathSegment)
        } else {
            type = when (formatHint) {
                FORMAT_SS -> C.CONTENT_TYPE_SS
                FORMAT_DASH -> C.CONTENT_TYPE_DASH
                FORMAT_HLS -> C.CONTENT_TYPE_HLS
                FORMAT_OTHER -> C.CONTENT_TYPE_OTHER
                else -> -1
            }
        }
        val mediaItemBuilder = MediaItem.Builder()
        mediaItemBuilder.setUri(uri)
        if (!cacheKey.isNullOrEmpty()) {
            mediaItemBuilder.setCustomCacheKey(cacheKey)
        }
        if (liveTargetOffsetMs > 0) {
            // Crinza patch: hold every viewer the same distance behind the
            // live edge — ExoPlayer nudges playback speed inside the bounds
            // to keep the offset, so staggered joiners converge.
            // Bounds were tried here (min/max offset) and removed: this
            // stream's playlist does not give ExoPlayer what it needs to
            // compute a live edge, so the whole LiveConfiguration is
            // largely inert — a 6s maxOffsetMs did not stop a measured
            // 15s. Position is controlled by seekToLiveOffset() instead.
            mediaItemBuilder.setLiveConfiguration(
                MediaItem.LiveConfiguration.Builder()
                    .setTargetOffsetMs(liveTargetOffsetMs)
                    // 1.0, NOT 0.97. A live player must never be allowed
                    // to run slower than real time: the deficit is
                    // cumulative, so 0.97 sheds ~1.8s of ground per
                    // minute and walks the playhead off the back of the
                    // 30s window — observed in the field as
                    // BehindLiveWindowException, a re-prepare loop, and
                    // latency that climbs the longer a class runs.
                    // Catching up (1.06) is safe; falling behind is not.
                    .setMinPlaybackSpeed(1.0f)
                    .setMaxPlaybackSpeed(1.06f)
                    .build()
            )
        }
        val mediaItem = mediaItemBuilder.build()
        var drmSessionManagerProvider: DrmSessionManagerProvider? = null
        drmSessionManager?.let { drmSessionManager ->
            drmSessionManagerProvider = DrmSessionManagerProvider { drmSessionManager }
        }

        return when (type) {
            C.CONTENT_TYPE_SS -> SsMediaSource.Factory(
                DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider!!)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(
                DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider!!)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(mediaDataSourceFactory)
                .apply {
                    if (drmSessionManagerProvider != null) {
                        setDrmSessionManagerProvider(drmSessionManagerProvider!!)
                    }
                }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_OTHER -> ProgressiveMediaSource.Factory(
                mediaDataSourceFactory,
                DefaultExtractorsFactory()
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider!!)
                }
            }.createMediaSource(mediaItem)

            else -> {
                throw IllegalStateException("Unsupported type: $type")
            }
        }
    }

    private fun setupVideoPlayer(
        eventChannel: EventChannel, textureEntry: SurfaceTextureEntry, result: MethodChannel.Result
    ) {
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(o: Any?, sink: EventSink) {
                    eventSink.setDelegate(sink)
                }

                override fun onCancel(o: Any?) {
                    eventSink.setDelegate(null)
                }
            },
        )
        surface = Surface(textureEntry.surfaceTexture())
        exoPlayer?.setVideoSurface(surface)
        setAudioAttributes(exoPlayer, true)
        exoPlayer?.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_BUFFERING -> {
                        sendBufferingUpdate(true)
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingStart"
                        eventSink.success(event)
                    }

                    Player.STATE_READY -> {
                        if (!isInitialized) {
                            isInitialized = true
                            sendInitialized()
                        }
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingEnd"
                        eventSink.success(event)
                    }

                    Player.STATE_ENDED -> {
                        val event: MutableMap<String, Any?> = HashMap()
                        event["event"] = "completed"
                        event["key"] = key
                        eventSink.success(event)
                    }

                    Player.STATE_IDLE -> {
                        //no-op
                    }
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                eventSink.error("VideoError", "Video player had error $error", "")
            }
        })
        val reply: MutableMap<String, Any> = HashMap()
        reply["textureId"] = textureEntry.id()
        result.success(reply)
    }

    fun sendBufferingUpdate(isFromBufferingStart: Boolean) {
        val bufferedPosition = exoPlayer?.bufferedPosition ?: 0L
        if (isFromBufferingStart || bufferedPosition != lastSendBufferedPosition) {
            val event: MutableMap<String, Any> = HashMap()
            event["event"] = "bufferingUpdate"
            val range: List<Number?> = listOf(0, bufferedPosition)
            // iOS supports a list of buffered ranges, so here is a list with a single range.
            event["values"] = listOf(range)
            eventSink.success(event)
            lastSendBufferedPosition = bufferedPosition
        }
    }

    @Suppress("DEPRECATION")
    private fun setAudioAttributes(exoPlayer: ExoPlayer?, mixWithOthers: Boolean) {
        val audioComponent = exoPlayer?.audioComponent ?: return
        audioComponent.setAudioAttributes(
            AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
            !mixWithOthers
        )

    }

    fun play() {
        exoPlayer?.playWhenReady = true
    }

    fun pause() {
        exoPlayer?.playWhenReady = false
    }

    fun setLooping(value: Boolean) {
        exoPlayer?.repeatMode = if (value) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
    }

    fun setVolume(value: Double) {
        val bracketedValue = max(0.0, min(1.0, value))
            .toFloat()
        exoPlayer?.volume = bracketedValue
    }

    fun setSpeed(value: Double) {
        val bracketedValue = value.toFloat()
        val playbackParameters = PlaybackParameters(bracketedValue)
        exoPlayer?.playbackParameters = playbackParameters
    }

    fun setTrackParameters(width: Int, height: Int, bitrate: Int) {
        val parametersBuilder = trackSelector.buildUponParameters()
        if (width != 0 && height != 0) {
            parametersBuilder.setMaxVideoSize(width, height)
        }
        if (bitrate != 0) {
            parametersBuilder.setMaxVideoBitrate(bitrate)
        }
        if (width == 0 && height == 0 && bitrate == 0) {
            parametersBuilder.clearVideoSizeConstraints()
            parametersBuilder.setMaxVideoBitrate(Int.MAX_VALUE)
        }
        trackSelector.setParameters(parametersBuilder)
    }

    fun seekTo(location: Int) {
        exoPlayer?.seekTo(location.toLong())
    }

    val position: Long
        get() = exoPlayer?.currentPosition ?: 0L

    /// Crinza patch: seek to exactly [offsetMs] behind the live edge,
    /// reading the edge from the timeline **at the moment of the seek**.
    ///
    /// This exists because the Dart side cannot do it correctly: the
    /// duration it holds is a one-time snapshot from `initialized` and is
    /// never refreshed, so a seek computed there lands
    /// `startup-elapsed + offset` behind live instead of `offset`.
    /// Reading `window.durationMs` here is always current.
    ///
    /// Returns the resulting offset in ms, or -1 if the timeline is not
    /// live / not ready.
    fun seekToLiveOffset(offsetMs: Long): Long {
        // Negative results are diagnostic codes, not failures to hide:
        //   -1 no player / empty timeline
        //   -2 window duration unknown (not a live window we can measure)
        //   -3 already closer to live than the target (forward-only)
        //   -4 nothing buffered ahead of the playhead yet
        val player = exoPlayer ?: return -1L
        val timeline = player.currentTimeline
        if (timeline.isEmpty) return -1L
        val window = Timeline.Window()
        timeline.getWindow(player.currentMediaItemIndex, window)
        val durationMs = window.durationMs
        if (durationMs == C.TIME_UNSET || durationMs <= 0L) return -2L
        var target = (durationMs - offsetMs).coerceAtLeast(0L)
        // NEVER seek past what has actually been downloaded. `durationMs`
        // is the playlist's live edge, but the bytes for it may not be
        // here yet — seeking there leaves the player waiting forever for
        // data that does not exist, which presents as a class stuck on
        // the loading spinner. Staying a second inside the buffered range
        // keeps the seek to content we can actually play.
        // No buffered-data clamp. It was added on the theory that seeking
        // past downloaded bytes caused a hang; the logs disproved that —
        // the hang was BehindLiveWindowException re-preparing in a loop,
        // and the clamp's only effect was to skip the seek entirely at
        // join time ("nothing buffered ahead yet"), which is exactly when
        // it is needed. ExoPlayer fetches what a seek asks for.
        if (target > durationMs) target = durationMs
        // Forward-only: a player already closer to live than the target
        // is where we want it, and yanking it back only adds latency.
        if (target <= player.currentPosition) return -3L
        player.seekTo(target)
        return durationMs - target
    }

    /// Crinza patch: everything needed to split measured latency into
    /// "where our player sits" vs "how old the newest segment already is
    /// when it reaches us". `windowStartTimeMs` is wall-clock, taken from
    /// EXT-X-PROGRAM-DATE-TIME; when the playlist carries it,
    /// `windowStartTimeMs + durationMs` is the real-world moment the live
    /// edge was captured, and the gap to `now` is the upstream pipeline
    /// delay — encoder + packager + CDN — measured, not guessed.
    fun liveDebugInfo(): Map<String, Any> {
        val player = exoPlayer ?: return mapOf("ok" to false)
        val timeline = player.currentTimeline
        if (timeline.isEmpty) return mapOf("ok" to false)
        val w = Timeline.Window()
        timeline.getWindow(player.currentMediaItemIndex, w)
        return mapOf(
            "ok" to true,
            "isLive" to w.isLive(),
            "durationMs" to w.durationMs,
            "windowStartTimeMs" to w.windowStartTimeMs,
            "positionMs" to player.currentPosition,
            "bufferedMs" to player.bufferedPosition,
            "liveOffsetMs" to currentLiveOffset,
            "nowMs" to System.currentTimeMillis()
        )
    }

    /// Crinza patch: ExoPlayer's own answer to "how far behind the live
    /// edge am I, right now, in ms". This is the only number that can
    /// separate a player sitting too far back from a pipeline (encoder,
    /// packager, CDN) that is simply slow — glass-to-glass latency alone
    /// cannot. Returns -1 when the stream is not live or the offset is
    /// not yet known.
    val currentLiveOffset: Long
        get() {
            val offset = exoPlayer?.currentLiveOffset ?: C.TIME_UNSET
            return if (offset == C.TIME_UNSET) -1L else offset
        }

    val absolutePosition: Long
        get() {
            val timeline = exoPlayer?.currentTimeline
            timeline?.let {
                if (!timeline.isEmpty) {
                    val windowStartTimeMs =
                        timeline.getWindow(0, Timeline.Window()).windowStartTimeMs
                    val pos = exoPlayer?.currentPosition ?: 0L
                    return windowStartTimeMs + pos
                }
            }
            return exoPlayer?.currentPosition ?: 0L
        }

    private fun sendInitialized() {
        if (isInitialized) {
            val event: MutableMap<String, Any?> = HashMap()
            event["event"] = "initialized"
            event["key"] = key
            event["duration"] = getDuration()
            if (exoPlayer?.videoFormat != null) {
                val videoFormat = exoPlayer.videoFormat
                var width = videoFormat?.width
                var height = videoFormat?.height
                val rotationDegrees = videoFormat?.rotationDegrees
                // Switch the width/height if video was taken in portrait mode
                if (rotationDegrees == 90 || rotationDegrees == 270) {
                    width = exoPlayer.videoFormat?.height
                    height = exoPlayer.videoFormat?.width
                }
                event["width"] = width
                event["height"] = height
            }
            eventSink.success(event)
        }
    }

    private fun getDuration(): Long = exoPlayer?.duration ?: 0L

    /**
     * Create media session which will be used in notifications, pip mode.
     *
     * @param context                - android context
     * @return - configured MediaSession instance
     */
    @SuppressLint("InlinedApi")
    fun setupMediaSession(context: Context?): MediaSessionCompat? {
        mediaSession?.release()
        context?.let {

            val mediaButtonIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0, mediaButtonIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            val mediaSession = MediaSessionCompat(context, TAG, null, pendingIntent)
            mediaSession.setCallback(object : MediaSessionCompat.Callback() {
                override fun onSeekTo(pos: Long) {
                    sendSeekToEvent(pos)
                    super.onSeekTo(pos)
                }
            })
            mediaSession.isActive = true
//            val mediaSessionConnector = MediaSessionConnector(mediaSession)
//            mediaSessionConnector.setPlayer(exoPlayer)
            this.mediaSession = mediaSession
            return mediaSession
        }
        return null

    }

    fun onPictureInPictureStatusChanged(inPip: Boolean) {
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = if (inPip) "pipStart" else "pipStop"
        eventSink.success(event)
    }

    fun disposeMediaSession() {
        if (mediaSession != null) {
            mediaSession?.release()
        }
        mediaSession = null
    }

    fun setAudioTrack(name: String, index: Int) {
        try {
            val mappedTrackInfo = trackSelector.currentMappedTrackInfo
            if (mappedTrackInfo != null) {
                for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
                    if (mappedTrackInfo.getRendererType(rendererIndex) != C.TRACK_TYPE_AUDIO) {
                        continue
                    }
                    val trackGroupArray = mappedTrackInfo.getTrackGroups(rendererIndex)
                    var hasElementWithoutLabel = false
                    var hasStrangeAudioTrack = false
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val format = group.getFormat(groupElementIndex)
                            if (format.label == null) {
                                hasElementWithoutLabel = true
                            }
                            if (format.id != null && format.id == "1/15") {
                                hasStrangeAudioTrack = true
                            }
                        }
                    }
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val label = group.getFormat(groupElementIndex).label
                            if (name == label && index == groupIndex) {
                                setAudioTrack(rendererIndex, groupIndex)
                                return
                            }

                            ///Fallback option
                            if (!hasStrangeAudioTrack && hasElementWithoutLabel && index == groupIndex) {
                                setAudioTrack(rendererIndex, groupIndex)
                                return
                            }
                            ///Fallback option
                            if (hasStrangeAudioTrack && name == label) {
                                setAudioTrack(rendererIndex, groupIndex)
                                return
                            }
                        }
                    }
                }
            }
        } catch (exception: Exception) {
            Log.e(TAG, "setAudioTrack failed$exception")
        }
    }

    private fun setAudioTrack(rendererIndex: Int, groupIndex: Int) {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo
        if (mappedTrackInfo != null) {
            val builder = trackSelector.parameters.buildUpon()
                .setRendererDisabled(rendererIndex, false)
                .addOverride(
                    TrackSelectionOverride(
                        mappedTrackInfo.getTrackGroups(rendererIndex).get(groupIndex),
                        mappedTrackInfo.getTrackGroups(rendererIndex)
                            .indexOf(mappedTrackInfo.getTrackGroups(rendererIndex).get(groupIndex))
                    )
                )

            trackSelector.setParameters(builder)
        }
    }

    private fun sendSeekToEvent(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = "seek"
        event["position"] = positionMs
        eventSink.success(event)
    }

    fun setMixWithOthers(mixWithOthers: Boolean) {
        setAudioAttributes(exoPlayer, mixWithOthers)
    }

    fun dispose() {
        disposeMediaSession()
        disposeRemoteNotifications()
        if (isInitialized) {
            exoPlayer?.stop()
        }
        textureEntry.release()
        eventChannel.setStreamHandler(null)
        surface?.release()
        exoPlayer?.release()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || javaClass != other.javaClass) return false
        val that = other as BetterPlayer
        if (if (exoPlayer != null) exoPlayer != that.exoPlayer else that.exoPlayer != null) return false
        return if (surface != null) surface == that.surface else that.surface == null
    }

    override fun hashCode(): Int {
        var result = exoPlayer?.hashCode() ?: 0
        result = 31 * result + if (surface != null) surface.hashCode() else 0
        return result
    }

    companion object {
        private const val TAG = "BetterPlayer"
        private const val FORMAT_SS = "ss"
        private const val FORMAT_DASH = "dash"
        private const val FORMAT_HLS = "hls"
        private const val FORMAT_OTHER = "other"
        private const val DEFAULT_NOTIFICATION_CHANNEL = "BETTER_PLAYER_NOTIFICATION"
        private const val NOTIFICATION_ID = 20772077

        //Clear cache without accessing BetterPlayerCache.
        fun clearCache(context: Context?, result: MethodChannel.Result) {
            try {
                context?.let {
                    val file = File(it.cacheDir, "betterPlayerCache")
                    deleteDirectory(file)
                }
                result.success(null)
            } catch (exception: Exception) {
                Log.e(TAG, exception.toString())
                result.error("", "", "")
            }
        }

        private fun deleteDirectory(file: File) {
            if (file.isDirectory) {
                val entries = file.listFiles()
                if (entries != null) {
                    for (entry in entries) {
                        deleteDirectory(entry)
                    }
                }
            }
            if (!file.delete()) {
                Log.e(TAG, "Failed to delete cache dir.")
            }
        }

        //Start pre cache of video. Invoke work manager job and start caching in background.
        fun preCache(
            context: Context?, dataSource: String?, preCacheSize: Long,
            maxCacheSize: Long, maxCacheFileSize: Long, headers: Map<String, String?>,
            cacheKey: String?, result: MethodChannel.Result
        ) {
            val dataBuilder = Data.Builder()
                .putString(BetterPlayerPlugin.URL_PARAMETER, dataSource)
                .putLong(BetterPlayerPlugin.PRE_CACHE_SIZE_PARAMETER, preCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_SIZE_PARAMETER, maxCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_FILE_SIZE_PARAMETER, maxCacheFileSize)
            if (cacheKey != null) {
                dataBuilder.putString(BetterPlayerPlugin.CACHE_KEY_PARAMETER, cacheKey)
            }
            for (headerKey in headers.keys) {
                dataBuilder.putString(
                    BetterPlayerPlugin.HEADER_PARAMETER + headerKey,
                    headers[headerKey]
                )
            }
            if (dataSource != null && context != null) {
                val cacheWorkRequest = OneTimeWorkRequest.Builder(CacheWorker::class.java)
                    .addTag(dataSource)
                    .setInputData(dataBuilder.build()).build()
                WorkManager.getInstance(context).enqueue(cacheWorkRequest)
            }
            result.success(null)
        }

        //Stop pre cache of video with given url. If there's no work manager job for given url, then
        //it will be ignored.
        fun stopPreCache(context: Context?, url: String?, result: MethodChannel.Result) {
            if (url != null && context != null) {
                WorkManager.getInstance(context).cancelAllWorkByTag(url)
            }
            result.success(null)
        }
    }

}