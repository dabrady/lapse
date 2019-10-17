#! /bin/bash

# TARGET_PROJECT=
# TARGET_FILE=
# SPEED=
TARGET_REVISION_RANGE=${TARGET_REVISION_RANGE:-master}
SPEED=${SPEED:-0.2}
HISTORY="$PWD/tmp.hist"
OUTPUT="$PWD/tmp.out"

[ -z "$TARGET_PROJECT" ] && echo "Missing TARGET_PROJECT" && exit 1
[ -z "$TARGET_FILE" ] && echo "Missing TARGET_FILE" && exit 1
[ ! -z "$(git -C $TARGET_PROJECT status --porcelain)" ] && echo "Target project not clean, bailing" && exit 1

function MakeTheUserWait() {
    while :; do
        for c in / - \\ \|; do
            printf '%s\b' "$c"
            sleep 0.1
        done
    done
}

function WaitFor() {
    MakeTheUserWait &
    local waitPID=$!

    local result=$($@)

    { kill $waitPID && wait $waitPID; } 2>/dev/null

    echo "$result"
}

function GenerateFileHistory() {
    git -C $TARGET_PROJECT log --follow --pretty=format:%h --name-status $TARGET_REVISION_RANGE -- $TARGET_FILE | tail -r | gsed -r '/^\s*$/d' > $HISTORY
}

function Cleanup() {
    [ -e "$HISTORY" ] && rm "$HISTORY"
    [ -e "$OUTPUT" ] && rm "$OUTPUT"
}

function WalkHistory() {
    local mode filenames sha
    while read -r mode filenames; do
        read -r sha

        if [[ "$mode" == D* ]]; then
            # The file was deleted in this commit, which means (because of how
            # the history was gathered) the next commit will have a 'rename'.
            # So we skip this commit.
            continue;
        fi

        # Thanks to the way we've gathered our history, we might have one or two
        # names listed for our target file due to renames. This breaks them into
        # separate variables for easy consumption.
        local oldFilename newFilename targetFilename
        read -r oldFilename newFilename <<< $filenames

        # For normal modifications, we'll only have the "old filename". But for
        # renames, we'll have both, and we care about the new name.
        if [[ -z "$newFilename" ]]; then
            targetFilename="$oldFilename"
        else
            targetFilename="$newFilename"
        fi

        # Execute given commands
        $@ $sha $targetFilename
    done <<< "$(cat "$HISTORY")"
}

function GetMaxLines() {
    [ -e "$HISTORY" ] || (echo "no history yet" && exit 1)
    local max=0
    function updateMax() {
        local sha="$1"
        local file="$2"
        local cur=$(((git -C $TARGET_PROJECT show $sha:$file 2>/dev/null || echo 0) | wc -l) | tr -d '[:space:]')
        if [ "$cur" -gt "$max" ]; then
            max=$cur
        fi
    }

    WalkHistory updateMax

    echo $max
}

function GenerateWatchPanes() {
    local fileLineCount="$1"
    [ -z "$fileLineCount" ] && echo "error: give me the longest line count of the file to watch" && exit 1

    # Create the visualization window.
    # NOTE This profile must exist: it determines the look-and-feel of our
    # visualization, particularly the font size. My preference is a profile
    # with tiny font (size 2).
    osascript -e 'tell application "iTerm2" to select (create window with profile "TINY")'

    # NOTE Need to run this in the visualization window since the display might be different from the one that executed this program.
    local visibleLineCount=$(osascript -e 'tell application "iTerm2" to tell current session of current window to return ""&rows')
    [ -z "$visibleLineCount" ] && echo "error: could not get visible line count" && osascript -e 'tell application "iTerm2" to tell current window to close' && exit 1

    # Divide the number of lines we need to show by the number of visible lines on the screen,
    # rounding up to the nearest whole number.
    local numPanes=$(( ( visibleLineCount - 1 + fileLineCount ) / visibleLineCount))

    # Turn off shell wildcard/"glob" expansion; needed because of the use of '*' in the lines below :P
    set -f
    for (( i=1; i<="$numPanes"; i++ )); do
        # This identifies the first line of the file that will be watched for the current pane.
        # It's 1 for the first pane, and a multiple of the visible number of lines for the rest.
        # NOTE We can use the shell variable `LINES` in the final command, since it will be executed in the shell itself.
        local startingLine=$([ 1 == "$i" ] && echo "1" || echo "\$((LINES * ($i - 1)))")

        # So. Many. Escapes. Took me over an hour to get this to compile. >.<
        local command="watch -tn 0.1 -d \\\"sed -n \\\\\\\"$startingLine,\$((LINES * $i))p;\$((LINES * $i))q\\\\\\\" $OUTPUT | cut -c -\${COLUMNS}\\\""
        osascript <<END
tell application "iTerm2"
    tell current session of current window
        set command to "$command"
        write text command

        # When we've reached the last pane, don't spawn another one.
        if $i is $numPanes then
           repeat
               delay 1
               if not (is processing) then exit repeat
           end repeat
        else
           tell (split vertically with same profile) to select
        end if
    end tell
end tell
END
    done
    # Turn shell wildcard expansion back on
    set +f
}

function ReplayHistory() {
    function replayCommit() {
        local sha="$1"
        local file="$2"
        git -C $TARGET_PROJECT show $sha:$file > $OUTPUT
        sleep $SPEED
    }

    # Time travel.
    touch $OUTPUT
    WalkHistory replayCommit

    # Give the user a bit of time to breathe at the end before resetting.
    sleep 2

    git -C $TARGET_PROJECT checkout master >/dev/null
    git -C $TARGET_PROJECT reset --hard origin/master >/dev/null
}

echo -n "Generating file history "
MakeTheUserWait &
GenerateFileHistory && { kill %1 && wait %1; } 2>/dev/null
echo -e "\b...done."

echo -n "Calculating maximum line count of file "
MakeTheUserWait &
MAX_LINES=$(GetMaxLines)
{ kill %1 && wait %1; } 2>/dev/null
echo -e "\b...done."

echo -n "Starting visualization"
GenerateWatchPanes $MAX_LINES
echo "...done."

# Fun little countdown. Entirely unecessary.
for (( i=1; i<=3; i++ )); do echo -n "$i.."; sleep 1; done
echo "starting."
ReplayHistory

Cleanup
## TODO Return focus to main terminal.
echo "Visualization complete."
