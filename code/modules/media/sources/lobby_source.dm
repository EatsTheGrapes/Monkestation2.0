GLOBAL_DATUM_INIT(lobby_media, /datum/media_source/lobby, new)

/// A media source for lobby music.
/datum/media_source/lobby
	volume = 85
	mixer_channel = CHANNEL_LOBBYMUSIC

/datum/media_source/lobby/get_priority(mob/target)
	if(CONFIG_GET(flag/disallow_title_music))
		return -1
	if(target?.client?.prefs?.channel_volume["[CHANNEL_LOBBYMUSIC]"] > 0)
		return INFINITY
	return -1

/// Snapshot a finite, deduplicated candidate set. Reports never change the
/// shared song or blacklist a URL for another listener.
/datum/media_source/lobby/proc/build_fallback_candidates(list/failed_urls, list/tracks = null)
	if(isnull(tracks))
		tracks = SSmedia_tracks.lobby_tracks
	var/list/eligible = list()
	var/list/seen_urls = list()
	for(var/datum/media_track/track as anything in tracks)
		if(QDELETED(track) || !track.lobby || !istext(track.url) || !length(trim(track.url)) || (track.url in failed_urls) || (track.url in seen_urls))
			continue
		seen_urls += track.url
		eligible += track
	return eligible

/datum/media_source/lobby/proc/pick_fallback_track(list/failed_urls, list/tracks = null)
	var/list/eligible = build_fallback_candidates(failed_urls, tracks)
	return length(eligible) ? pick(eligible) : null

/datum/media_source/lobby/proc/retry_failed_track(mob/listener, datum/media_player/player, failed_url)
	if(QDELETED(listener) || QDELETED(player) || listener.client != player.owner || listener.current_media_source != src)
		return
	if(get_priority(listener) <= 0)
		return
	var/datum/media_track/expected_track = player.lobby_track_override ? player.lobby_track_override : current_track
	if(QDELETED(expected_track) || failed_url != expected_track.url)
		return
	if(!player.failed_lobby_urls)
		player.failed_lobby_urls = list()
	if(failed_url in player.failed_lobby_urls)
		return
	player.failed_lobby_urls += failed_url
	player.lobby_load_failures++
	// Snapshot once. Later catalog changes cannot extend this chain, and
	// consuming before play prevents duplicate callbacks from retrying a URL.
	if(isnull(player.lobby_fallback_candidates))
		player.lobby_fallback_candidates = build_fallback_candidates(player.failed_lobby_urls)
	var/datum/media_track/track
	while(length(player.lobby_fallback_candidates))
		var/datum/media_track/candidate = pick(player.lobby_fallback_candidates)
		player.lobby_fallback_candidates -= candidate
		if(QDELETED(candidate) || !candidate.lobby || !istext(candidate.url) || !length(trim(candidate.url)) || (candidate.url in player.failed_lobby_urls))
			continue
		track = candidate
		break
	if(!track)
		to_chat(listener, span_notice("No remaining lobby music tracks could be loaded."))
		return
	player.lobby_track_override = track
	to_chat(listener, span_notice("Skipping unavailable lobby music. Trying <b>[track.title]</b> by <b>[track.artist]</b>."))
	play_for_listener(listener, player)

/datum/media_source/lobby/play_for_listener(mob/target, datum/media_player/player, update_time = FALSE)
	if(QDELETED(src) || QDELETED(player) || QDELETED(target) || target.client != player.owner || target.current_media_source != src)
		return
	// Respect both configuration and the listener's lobby-channel preference
	// if either changed while a failed load was being reported.
	if(get_priority(target) <= 0)
		return
	var/datum/media_track/track = player.lobby_track_override ? player.lobby_track_override : current_track
	if(QDELETED(track) || !istext(track.url) || !length(track.url) || (track.url in player.failed_lobby_urls))
		return
	var/volume = get_volume(target)
	if(player.current_url == track.url)
		player.set_volume(volume)
		player.set_position(0, 0, 0)
		player.set_panning(0)
	else
		player.play(track.url, volume)
	if(update_time && !player.lobby_track_override)
		var/time = get_current_time()
		if(time > 0)
			player.set_time(time)
