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

echo -n "Generating file history..."
MakeTheUserWait &
WAIT_PID=$!

GenerateFileHistory

{ kill $WAIT_PID && wait $WAIT_PID; } 2>/dev/null

echo -e "done."
echo -n "Calculating maximum line count of file..."
MakeTheUserWait &
WAIT_PID=$!

MAX_LINES=$(GetMaxLines)

{ kill $WAIT_PID && wait $WAIT_PID; } 2>/dev/null

echo -e "done. Max length is $MAX_LINES lines."
ClearFileHistory

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
