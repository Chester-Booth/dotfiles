#!/bin/bash

# Get the current file from the temporary file
if [ -f /tmp/waybar-todo-current-file ]; then
    current_file=$(cat /tmp/waybar-todo-current-file)
else
    current_file="$HOME/Documents/todo/1-todo.md"
fi

## if current file is 2-gcal.md or 99-gcal_week.md set to todo
if [[ "$current_file" == *"2-gcal.md"* || "$current_file" == *"99-gcal_week.md"* ]]; then
    current_file="$HOME/Documents/todo/1-todo.md"
fi


# Open the current file in kitty with micro editor and glow preview
kitty --class todo --title todo sh -c "micro '$current_file' && glow '$current_file' && echo 'Done - press enter'; read"