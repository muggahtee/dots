function spotify() {

  showHelp () {
    echo "Usage:";
    echo;
    echo "  $(basename "$0") <command>";
    echo;
    echo "Commands:";
    echo;
    echo "  play                         # Resumes playback where Spotify last left off.";
    echo "  play [song name]             # Finds a song by name and plays it.";
    echo "  play album [album name]      # Finds an album by name and plays it.";
    echo "  play artist [artist name]    # Finds an artist by name and plays it.";
    echo "  play list [playlist name]    # Finds a playlist by name and plays it.";
    echo "  pause                        # Pauses Spotify playback.";
    echo "  next                         # Skips to the next song in a playlist.";
    echo "  prev                         # Returns to the previous song in a playlist.";
    echo "  pos [time]                   # Jumps to a time (in secs) in the current song.";
    echo "  quit                         # Stops playback and quits Spotify.";
    echo;
    echo "  vol up                       # Increases the volume by 10%.";
    echo "  vol down                     # Decreases the volume by 10%.";
    echo "  vol [amount]                 # Sets the volume to an amount between 0 and 100.";
    echo "  vol show                     # Shows the current Spotify volume.";
    echo;
    echo "  status                       # Shows the current player status.";
    echo "  share                        # Copies the current song URL to the clipboard."
    echo "  info                         # Shows Full Information about song that is playing.";
    echo;
    echo "  toggle shuffle               # Toggles shuffle playback mode.";
    echo "  toggle repeat                # Toggles repeat playback mode.";
  }

  cecho(){
    bold=$(tput bold);
    green=$(tput setaf 2);
    reset=$(tput sgr0);
    echo "$bold$green$1$reset";
  }

  showStatus () {
      state=$(osascript -e 'tell application "Spotify" to player state as string');
      cecho "Spotify is currently $state.";
      if [ "$state" = "playing" ]; then
        artist=$(osascript -e 'tell application "Spotify" to artist of current track as string');
        album=$(osascript -e 'tell application "Spotify" to album of current track as string');
        track=$(osascript -e 'tell application "Spotify" to name of current track as string');
        duration=$(osascript -e 'tell application "Spotify" to duration of current track as string');
        duration=$(echo "scale=2; $duration / 60 / 1000" | bc);
        position=$(osascript -e 'tell application "Spotify" to player position as string' | tr ',' '.');
        position=$(echo "scale=2; $position / 60" | bc | awk '{printf "%0.2f", $0}');

        printf "$reset""Artist: %s\nAlbum: %s\nTrack: %s \nPosition: %s / %s\n" "$artist" "$album" "$track" "$position" "$duration";
      fi
  }



  if [ $# = 0 ]; then
    showHelp;
  else
    if [ "$1" != "quit" ] && [ "$(osascript -e 'application "Spotify" is running')" = "false" ]; then
      osascript -e 'tell application "Spotify" to activate'
      sleep 2
    fi
  fi

  while [ $# -gt 0 ]; do
    arg=$1;

    case $arg in
      "play"    )
        if [ $# != 1 ]; then
          # There are additional arguments, so find out how many
          array=( $@ );
          len=${#array[@]};
          SPOTIFY_SEARCH_API="https://api.spotify.com/v1/search"
          SPOTIFY_PLAY_URI="";

          searchAndPlay() {
            type="$1"
            Q="$2"

            cecho "Searching ${type}s for: $Q";

            SPOTIFY_PLAY_URI=$( \
              curl -s -G $SPOTIFY_SEARCH_API --data-urlencode "q=$Q" -d "type=$type&limit=1&offset=0" -H "Accept: application/json" \
              | grep -E -o "spotify:$type:[a-zA-Z0-9]+" -m 1
              )
          }

          case $2 in
            "list"  )
              _args=${array[*]:2:$len};
              Q=$_args;

              cecho "Searching playlists for: $Q";

              results=$( \
                curl -s -G $SPOTIFY_SEARCH_API --data-urlencode "q=$Q" -d "type=playlist&limit=10&offset=0" -H "Accept: application/json" \
                | grep -E -o "spotify:user:[a-zA-Z0-9_]+:playlist:[a-zA-Z0-9]+" -m 10 \
                )

              count=$( \
                echo "$results" | grep -c "spotify:user" \
                )

              if [ "$count" -gt 0 ]; then
                random=$(( RANDOM % count));

                SPOTIFY_PLAY_URI=$( \
                  echo "$results" | awk -v random="$random" '/spotify:user:[a-zA-Z0-9]+:playlist:[a-zA-Z0-9]+/{i++}i==random{print; exit}' \
                  )
              fi;;

            "album" | "artist" | "track"    )
              _args=${array[*]:2:$len};
              searchAndPlay "$2" "$_args";;

            *   )
              _args=${array[*]:1:$len};
              searchAndPlay track "$_args";;
          esac

          if [ "$SPOTIFY_PLAY_URI" != "" ]; then
            cecho "Playing ($Q Search) -> Spotify URL: $SPOTIFY_PLAY_URI";

            osascript -e "tell application \"Spotify\" to play track \"$SPOTIFY_PLAY_URI\"";

          else
            cecho "No results when searching for $Q";
          fi
        else
          # play is the only param
          cecho "Playing Spotify.";
          osascript -e 'tell application "Spotify" to play';
        fi
        break ;;

      "pause"    )
        state=$(osascript -e 'tell application "Spotify" to player state as string');
        if [ "$state" = "playing" ]; then
          cecho "Pausing Spotify.";
        else
          cecho "Playing Spotify.";
        fi

        osascript -e 'tell application "Spotify" to playpause';
        break ;;

      "quit"    )
        if [ "$(osascript -e 'application "Spotify" is running')" = "false" ]; then
          cecho "Spotify was not running."
        else
          cecho "Closing Spotify.";
          osascript -e 'tell application "Spotify" to quit';
        fi
        break ;;

      "next"    )
        cecho "Going to next track." ;
        osascript -e 'tell application "Spotify" to next track';
        break ;;

      "prev"    )
        cecho "Going to previous track.";
        osascript -e 'tell application "Spotify" to previous track';
        break ;;

      "vol"    )
        vol=$(osascript -e 'tell application "Spotify" to sound volume as integer');
        if [[ "$2" = "show" || "$2" = "" ]]; then
          cecho "Current Spotify volume level is $vol.";
          break ;
        elif [ "$2" = "up" ]; then
          if [ "$vol" -le 90 ]; then
            newvol=$(( vol+10 ));
            cecho "Increasing Spotify volume to $newvol.";
          else
            newvol=100;
            cecho "Spotify volume level is at max.";
          fi
        elif [ "$2" = "down" ]; then
          if [ "$vol" -ge 10 ]; then
            newvol=$(( vol-10 ));
            cecho "Reducing Spotify volume to $newvol.";
          else
            newvol=0;
            cecho "Spotify volume level is at min.";
          fi
        elif [ "$2" -ge 0 ]; then
          newvol=$2;
        fi

        osascript -e "tell application \"Spotify\" to set sound volume to $newvol";
        break ;;

      "toggle"  )
        if [ "$2" = "shuffle" ]; then
          osascript -e 'tell application "Spotify" to set shuffling to not shuffling';
          curr=$(osascript -e 'tell application "Spotify" to shuffling');
          cecho "Spotify shuffling set to $curr";
        elif [ "$2" = "repeat" ]; then
          osascript -e 'tell application "Spotify" to set repeating to not repeating';
          curr=$(osascript -e 'tell application "Spotify" to repeating');
          cecho "Spotify repeating set to $curr";
        fi
        break ;;

      "pos"   )
        cecho "Adjusting Spotify play position."
        osascript -e "tell application \"Spotify\" to set player position to $2";
        break ;;

      "status" )
        showStatus;
        break ;;

      "info" )
        info=$(osascript -e 'tell application "Spotify"
          set tM to round (duration of current track / 60) rounding down
          set tS to duration of current track mod 60
          set pos to player position as text
          set myTime to tM as text & "min " & tS as text & "s"
          set nM to round (player position / 60) rounding down
          set nS to round (player position mod 60) rounding down
          set nowAt to nM as text & "min " & nS as text & "s"
          set info to "" & "\nArtist:         " & artist of current track
          set info to info & "\nTrack:          " & name of current track
          set info to info & "\nAlbum Artist:   " & album artist of current track
          set info to info & "\nAlbum:          " & album of current track
          set info to info & "\nSeconds:        " & duration of current track
          set info to info & "\nSeconds played: " & pos
          set info to info & "\nDuration:       " & mytime
          set info to info & "\nNow at:         " & nowAt
          set info to info & "\nPlayed Count:   " & played count of current track
          set info to info & "\nTrack Number:   " & track number of current track
          set info to info & "\nPopularity:     " & popularity of current track
          set info to info & "\nId:             " & id of current track
          set info to info & "\nSpotify URL:    " & spotify url of current track
          set info to info & "\nArtwork:        " & artwork of current track
          set info to info & "\nPlayer:         " & player state
          set info to info & "\nVolume:         " & sound volume
          set info to info & "\nShuffle:        " & shuffling
          set info to info & "\nRepeating:      " & repeating
          end tell
          return info')
        echo "$info";
        break ;;

    "share"     )
      url=$(osascript -e 'tell application "Spotify" to spotify url of current track');
      remove='spotify:track:'
      url=${url#$remove}
      url="http://open.spotify.com/track/$url"
      cecho "Share URL: $url";
      cecho -n "$url" | pbcopy
      break;;

      -h|--help| *)
        showHelp;
        break ;;
    esac
  done
}
