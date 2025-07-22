function notes
    set -l notes_dir ~/notes
    set -l date_dir (date +%Y-%m-%d)
    set -l timestamp (date +%H-%M-%S)
    set -l datetime (date +"%Y-%m-%d %H:%M:%S")
    
    # Create notes directory if it doesn't exist
    mkdir -p $notes_dir/$date_dir
    
    # Determine filename and header
    if test (count $argv) -eq 0
        # No arguments - check for existing day file first
        set -l existing_day_file (ls $notes_dir/$date_dir/*.md 2>/dev/null | head -1)
        if test -n "$existing_day_file"
            nvim $existing_day_file
            return
        end
        set -l filename "$timestamp.md"
        set -l header "# Notes $datetime"
    else
        # With arguments - check for existing file with same name
        set -l existing_file (ls $notes_dir/$date_dir/$argv-*.md 2>/dev/null | head -1)
        if test -n "$existing_file"
            nvim $existing_file
            return
        end
        set -l filename "$argv-$timestamp.md"
        set -l header "# $argv"
    end
    
    # Create the full file path
    set -l filepath "$notes_dir/$date_dir/$filename"
    
    # Create the file with header if it doesn't exist
    if not test -f $filepath
        touch $filepath
        echo $header > $filepath
        echo "" >> $filepath
    end
    
    # Open neovim with the file
    nvim $filepath
end