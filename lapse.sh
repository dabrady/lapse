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

    RESULT=$($@)

    { kill $waitPID && wait $waitPID; } 2>/dev/null

    echo -n "$RESULT"
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
        cur=$(((git show $sha:$filename 2>/dev/null || echo 0) | wc -l) | tr -d '[:space:]')
        if [ "$cur" -gt "$max" ]; then
            max=$cur
        fi
    done <<< "$( cat "$HISTORY" | xargs -n2)"

    echo $max
}

function CalculateNumberOfPanesNeeded() {
    LINE_COUNT="$1"
    [ -z "$LINE_COUNT" ] && echo "error: no line count given" && exit 1

    echo 3
}

function GenerateWatchPanes() {
    NUM_PANES="$1"
    [ -z "$NUM_PANES" ] && echo "error: give me a number" && exit 1

    # TODO Update with actual watch command
    COMMAND="PS1=;echo Pane no."

    osascript <<END
tell application "iTerm2"
    # Create the visualization window.
    # NOTE This profile must exist: it determines the look-and-feel of our
    # visualization, particularly the font size. My preference is a profile
    # with tiny font (size 2).
    select (create window with profile "TINY")

    # Generate enough panes to visualize the TARGET_FILE at its longest.
    tell current session of current window
        set i to 1
        write text "$COMMAND"&i
        repeat with i from 2 to $NUM_PANES
            tell (split vertically with same profile)
                select
                write text "$COMMAND "&i
            end tell
        end repeat
    end tell
end tell
END
}

echo -n "Generating file history..."
WaitFor GenerateFileHistory
echo "done."

echo -n "Calculating maximum line count of file..."
MAX_LINES=5 #$(WaitFor GetMaxLines)

echo "done. Max length is $MAX_LINES lines."
ClearFileHistory

NUM_PANES=$(CalculateNumberOfPanesNeeded $MAX_LINES)

GenerateWatchPanes $NUM_PANES

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
