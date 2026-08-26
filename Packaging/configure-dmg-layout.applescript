on run argv
    if (count of argv) is not 2 then error "Expected the mounted DMG path and volume name"

    set mountPath to item 1 of argv
    set volumeName to item 2 of argv
    set backgroundAlias to POSIX file (mountPath & "/.background/arrow.png") as alias

    tell application "Finder"
        set mountedDisk to disk volumeName
        tell mountedDisk
            open
            delay 1

            -- Match the 640x360 background and leave enough room for both icons.
            set bounds of container window to {100, 100, 740, 460}
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false

            set iconViewOptions to icon view options of container window
            set arrangement of iconViewOptions to not arranged
            set icon size of iconViewOptions to 128
            set text size of iconViewOptions to 12
            set shows item info of iconViewOptions to false
            set background picture of iconViewOptions to backgroundAlias

            set position of item "AIUsageBar.app" to {150, 180}
            set position of item "Applications" to {490, 180}

            update without registering applications
            delay 2
            close
            delay 1
            open
            delay 2
            update without registering applications
            delay 2
        end tell
    end tell
end run
