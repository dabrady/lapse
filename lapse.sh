#! /bin/bash

# TARGET_PROJECT=
# TARGET_FILE=$2
TARGET_REVISION_RANGE=${TARGET_REVISION_RANGE:-master}
HISTORY="$PWD/tmp.hist"

[ -z "$TARGET_PROJECT" ] && echo "Missing TARGET_PROJECT" && exit 1
[ -z "$TARGET_FILE" ] && echo "Missing TARGET_FILE" && exit 1

pushd "$TARGET_PROJECT" >/dev/null

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
    git log --follow --format=format:%h --name-only $TARGET_REVISION_RANGE -- $TARGET_FILE | gsed -r '/^\s*$/d' > $HISTORY
}

function ClearFileHistory() {
    [ -e "$HISTORY" ] && rm "$HISTORY"
}

function GetMaxLines() {
    [ -e "$HISTORY" ] || (echo "no history yet" && exit 1)
    max=0
    while read sha filename; do
        # File renames result in a commit that touched the file, but in a file that no longer
        # exists on that commit -_-; they also result in a new file that we need to start tracking.
        # Gotta guard against it.
        [ -e $filename ] || git checkout $sha $filename 2>/dev/null || continue
        local cur=$(((git show $sha:$filename 2>/dev/null || echo 0) | wc -l) | tr -d '[:space:]')
        if [ "$cur" -gt "$max" ]; then
            max=$cur
        fi
    done <<< "$( cat "$HISTORY" | xargs -n2)"

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
        local command="cd $TARGET_PROJECT; watch -tn 0.1 -d \\\"sed -n \\\\\\\"$startingLine,\$((LINES * $i))p;\$((LINES * $i))q\\\\\\\" $TARGET_FILE | cut -c -\${COLUMNS}\\\""
        osascript <<END
tell application "iTerm2"
    tell current session of current window
        set command to "$command"
        write text command

        # When we've reached the last pane, don't spawn another one.
        if $i is not $numPanes then
           tell (split vertically with same profile) to select
        end if
    end tell
end tell
END
    done
    # Turn shell wildcard expansion back on
    set +f
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

ClearFileHistory

echo -n "Starting visualization"
GenerateWatchPanes $MAX_LINES
echo "...done."


### Example script to spawn new terminal and do something
# osascript <<ENDSCRIPT
# tell application "iTerm2"
#   tell current window
#     select (create tab with profile "sidebar")
#     tell current session of current tab
#       tell (split vertically with same profile)
#          write text "echo Hello"
#       end tell
#     end tell
#   end tell
# end tell
# ENDSCRIPT

### Replay file history
# for sha in $(git log --oneline --reverse --format=format:%H $TARGET_REVISION_RANGE -- $TARGET_FILE); do
#    git show $sha:$file > $OUTPUT
#    sleep 0.2
# done

# git checkout master

popd >/dev/null
