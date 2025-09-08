#!/data/data/com.termux/files/usr/bin/bash

if [[ -f /data/data/com.termux/files/usr/etc/termux-desktop/common_functions ]]; then
    source /data/data/com.termux/files/usr/etc/termux-desktop/common_functions
else
    echo -e "\033[0;31m[☓]\033[0;31m It looks like common_functions is missing from your system, make sure you install sabamdarif/termux-desktop\033[0m"
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly SCRIPT_DIR

get_script_parameter_value() {
    local filename=$1
    local parameter=$2

    grep --only-matching -m 1 "$parameter=[^\";]*" "$filename" | cut -d "=" -f 2 | tr -d "'" | tr "|" ";" 2>/dev/null
}

command_exists() {
    # This function checks whether a given command is available on the system.
    #
    # Parameters:
    #   - $1 (command_check): The name of the command to verify.

    local command_check=$1

    if command -v "$command_check" &>/dev/null; then
        return 0
    fi
    return 1
}

# Added nemo to the compatible file managers list
COMPATIBLE_FILE_MANAGERS=("nautilus" "caja" "nemo" "pcmanfm-qt" "thunar")
FILE_MANAGER=""
INSTALL_DIR=""

step_install_dependencies() {
    echo "${R}[${G}-${R}]${G} Installing the dependencies...${NC}"

    # Core utilities
    package_install_and_check "zenity xclip texlive-bin bzip2 gzip tar unzip zip xorriso optipng imagemagick ghostscript qpdf poppler tesseract tesseract ffmpeg rdfind exiftool go-findimagedupes mediainfo mp3gain id3v2 filelight perl rhash pandoc p7zip xz-utils iconv"

    # Fix ImageMagick PDF permissions
    local imagemagick_config="/data/data/com.termux/files/usr/etc/ImageMagick-7/policy.xml"
    if [[ -f "$imagemagick_config" ]]; then
        echo "${R}[${G}-${R}]${G} Fixing write permission with PDF in ImageMagick...${NC}"
        sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' "$imagemagick_config"
        sed -i 's/".GiB"/"8GiB"/g' "$imagemagick_config"
    fi
}

setup_file_manager() {
    local file_manager=""

    for file_manager in "${COMPATIBLE_FILE_MANAGERS[@]}"; do
        # Check if the file manager command exists.
        if command_exists "$file_manager"; then
            case "$file_manager" in
            "nautilus")
                INSTALL_DIR="$HOME/.local/share/nautilus/scripts"
                FILE_MANAGER="nautilus"
                ;;
            "caja")
                INSTALL_DIR="$HOME/.config/caja/scripts"
                FILE_MANAGER="caja"
                ;;
            "nemo")
                INSTALL_DIR="$HOME/.local/share/nemo/scripts"
                FILE_MANAGER="nemo"
                ;;
            "pcmanfm-qt")
                INSTALL_DIR="$HOME/.local/share/scripts"
                FILE_MANAGER="pcmanfm-qt"
                ;;
            "thunar")
                INSTALL_DIR="$HOME/.local/share/scripts"
                FILE_MANAGER="thunar"
                ;;
            esac

            check_and_create_directory "$INSTALL_DIR"

            return
        fi
    done

    print_failed "Error: could not find any compatible file managers!"
    exit 1
}

step_install_shortcuts_nautilus() {
    echo "${R}[${G}-${R}]${G} Installing the keyboard shortcuts for Nautilus...${NC}"

    local accels_file=$1
    mkdir --parents "$(dirname -- "$accels_file")"

    # Create a backup of older custom actions.
    check_and_backup "$accels_file"
    check_and_delete "$accels_file"

    {
        local filename=""
        while IFS="" read -r -d "" filename; do
            local install_keyboard_shortcut=""
            install_keyboard_shortcut=$(get_script_parameter_value "$filename" "install_keyboard_shortcut")

            if [[ -n "$install_keyboard_shortcut" ]]; then
                local name=""
                name=$(basename -- "$filename")
                printf "%s\n" "$install_keyboard_shortcut $name"
            fi
        done < <(find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated)

    } >"$accels_file"

    echo "${R}[${G}✓${R}]${G} Nautilus keyboard shortcuts installed successfully${NC}"
}

step_install_shortcuts_gnome2() {
    echo "${R}[${G}-${R}]${G} Installing the keyboard shortcuts...${NC}"

    local accels_file=$1
    mkdir --parents "$(dirname -- "$accels_file")"

    # Create a backup of older custom actions.
    check_and_backup "$accels_file"
    check_and_delete "$accels_file"

    {
        # Disable the shortcut for "OpenAlternate" (<control><shift>o).
        printf "%s\n" '(gtk_accel_path "<Actions>/DirViewActions/OpenAlternate" "")'
        # Disable the shortcut for "OpenInNewTab" (<control><shift>o).
        printf "%s\n" '(gtk_accel_path "<Actions>/DirViewActions/OpenInNewTab" "")'
        # Disable the shortcut for "Show Hide Extra Pane" (F3).
        printf "%s\n" '(gtk_accel_path "<Actions>/NavigationActions/Show Hide Extra Pane" "")'
        printf "%s\n" '(gtk_accel_path "<Actions>/ShellActions/Show Hide Extra Pane" "")'

        local filename=""
        while IFS="" read -r -d "" filename; do
            local install_keyboard_shortcut=""
            install_keyboard_shortcut=$(get_script_parameter_value "$filename" "install_keyboard_shortcut")
            install_keyboard_shortcut=${install_keyboard_shortcut//Control/Primary}

            if [[ -n "$install_keyboard_shortcut" ]]; then
                # Escape slashes and spaces for Gnome shortcut paths.
                # shellcheck disable=SC2001
                filename=$(sed "s|/|\\\\\\\\s|g; s| |%20|g" <<<"$filename")
                printf "%s\n" '(gtk_accel_path "<Actions>/ScriptsGroup/script_file:\\s\\s'"$filename"'" "'"$install_keyboard_shortcut"'")'
            fi
        done < <(find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated)

    } >"$accels_file"

    echo "${R}[${G}✓${R}]${G} Keyboard shortcuts installed successfully${NC}"
}

step_install_shortcuts_thunar() {
    echo "${R}[${G}-${R}]${G} Installing the keyboard shortcuts for Thunar...${NC}"

    local accels_file=$1
    mkdir --parents "$(dirname -- "$accels_file")"

    # Create a backup of older custom actions.
    check_and_backup "$accels_file"
    check_and_delete "$accels_file"

    {
        # Default Thunar shortcuts.
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActions/uca-action-1-1" "")'
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActions/uca-action-4-4" "")'
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActions/uca-action-3-3" "")'
        # Disable "<Primary><Shift>p".
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActionManager/open-in-new-tab" "")'
        # Disable "<Primary><Shift>o".
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActionManager/open-in-new-window" "")'
        # Disable "<Primary>e".
        printf "%s\n" '(gtk_accel_path "<Actions>/ThunarWindow/view-side-pane-tree" "")'

        local filename=""
        while IFS="" read -r -d "" filename; do
            local install_keyboard_shortcut=""
            install_keyboard_shortcut=$(get_script_parameter_value "$filename" "install_keyboard_shortcut")
            install_keyboard_shortcut=${install_keyboard_shortcut//Control/Primary}

            if [[ -n "$install_keyboard_shortcut" ]]; then
                local name=""
                local submenu=""
                local unique_id=""
                name=$(basename -- "$filename")
                submenu=$(dirname -- "$filename" | sed "s|.*scripts/|Scripts/|g")
                unique_id=$(echo -n "$submenu$name" | md5sum | sed "s|[^0-9]*||g" | cut -c 1-8)

                printf "%s\n" '(gtk_accel_path "<Actions>/ThunarActions/uca-action-'"$unique_id"'" "'"$install_keyboard_shortcut"'")'
            fi
        done < <(find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated)

    } >"$accels_file"
}

step_install_shortcuts() {
    case "$FILE_MANAGER" in
    "nautilus")
        step_install_shortcuts_nautilus "$HOME/.config/nautilus/scripts-accels"
        ;;
    "caja")
        step_install_shortcuts_gnome2 "$HOME/.config/caja/accels"
        ;;
    "nemo")
        step_install_shortcuts_gnome2 "$HOME/.gnome2/accels/nemo"
        ;;
    "thunar")
        step_install_shortcuts_thunar "$HOME/.config/Thunar/accels.scm"
        ;;
    esac
}

step_install_menus_pcmanfm() {
    echo "${R}[${G}-${R}]${G} Installing PCManFM-Qt actions...${NC}"

    local desktop_menus_dir="$HOME/.local/share/file-manager/actions"
    check_and_create_directory "$desktop_menus_dir"
    check_and_backup "$desktop_menus_dir"/*.desktop
    check_and_delete "$desktop_menus_dir"/*.desktop

    # Create the 'Scripts.desktop' menu.
    {
        printf "%s\n" "[Desktop Entry]"
        printf "%s\n" "Type=Menu"
        printf "%s\n" "Name=Scripts"
        printf "%s" "ItemsList="
        find -L "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d ! -path "*.git*" ! -path "*.assets*" -printf "%f\n" 2>/dev/null | sort | tr $'\n' ";" || true
        printf "\n"
    } >"${desktop_menus_dir}/Scripts.desktop"
    chmod +x "${desktop_menus_dir}/Scripts.desktop"

    # Create a '.desktop' file for each directory (for sub-menus).
    local filename=""
    local name=""
    local dir_items=""
    find -L "$INSTALL_DIR" -mindepth 1 -type d ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated |
        while IFS= read -r -d "" filename; do
            name=${filename##*/}
            dir_items=$(find -L "$filename" -mindepth 1 -maxdepth 1 ! -path "*.git*" ! -path "*.assets*" -printf "%f\n" 2>/dev/null | sort | tr $'\n' ";" || true)
            if [[ -z "$dir_items" ]]; then
                continue
            fi

            {
                printf "%s\n" "[Desktop Entry]"
                printf "%s\n" "Type=Menu"
                printf "%s\n" "Name=$name"
                printf "%s\n" "ItemsList=$dir_items"

            } >"${desktop_menus_dir}/$name.desktop"
            chmod +x "${desktop_menus_dir}/$name.desktop"
        done

    # Create a '.desktop' file for each script.
    while IFS="" read -r -d "" filename; do
        name=${filename##*/}

        # Set the mime requirements.
        local par_recursive=""
        local par_select_mime=""
        par_recursive=$(get_script_parameter_value "$filename" "par_recursive")
        par_select_mime=$(get_script_parameter_value "$filename" "par_select_mime")

        if [[ -z "$par_select_mime" ]]; then
            local par_type=""
            par_type=$(get_script_parameter_value "$filename" "par_type")

            case "$par_type" in
            "directory") par_select_mime="inode/directory" ;;
            "all") par_select_mime="all/all" ;;
            "file") par_select_mime="all/allfiles" ;;
            *) par_select_mime="all/allfiles" ;;
            esac
        fi

        if [[ "$par_recursive" == "true" ]]; then
            case "$par_select_mime" in
            "inode/directory") : ;;
            "all/all") : ;;
            "all/allfiles") par_select_mime="all/all" ;;
            *) par_select_mime+=";inode/directory" ;;
            esac
        fi

        par_select_mime="$par_select_mime;"
        # shellcheck disable=SC2001
        par_select_mime=$(sed "s|/;|/*;|g" <<<"$par_select_mime")

        local desktop_filename=""
        desktop_filename="${desktop_menus_dir}/${name}.desktop"
        {
            printf "%s\n" "[Desktop Entry]"
            printf "%s\n" "Type=Action"
            printf "%s\n" "Name=$name"
            printf "%s\n" "Profiles=scriptAction"
            printf "\n"
            printf "%s\n" "[X-Action-Profile scriptAction]"
            printf "%s\n" "MimeTypes=$par_select_mime"
            printf "%s\n" "Exec=bash \"$filename\" %F"
        } >"$desktop_filename"
        chmod +x "$desktop_filename"
    done < <(find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated)

    echo "${R}[${G}✓${R}]${G} PCManFM-Qt menus installed successfully${NC}"
}

step_install_menus_thunar() {
    echo "${R}[${G}-${R}]${G} Installing Thunar actions...${NC}"

    local menus_file="$HOME/.config/Thunar/uca.xml"
    local accels_file="$HOME/.config/Thunar/accels.scm"

    check_and_create_directory "$(dirname "$menus_file")"

    check_and_backup "$menus_file"
    check_and_backup "$accels_file"

    # First create the menu actions
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" >"$menus_file"
    echo "<actions>" >>"$menus_file"

    # Process each script file for menu actions
    while IFS= read -r -d '' script_file; do
        local menu_name=""
        local menu_path=""
        local unique_id=""

        menu_name=$(basename -- "$script_file")
        menu_path=$(dirname -- "$script_file" | sed "s|$INSTALL_DIR/||" | sed 's|/|/|g')
        menu_path="Scripts/$menu_path"
        unique_id=$(echo -n "$menu_path$menu_name" | md5sum | sed "s|[^0-9]*||g" | cut -c 1-8)

        # Add to uca.xml
        {
            echo "<action>"
            echo "    <icon></icon>"
            echo "    <name>$menu_name</name>"
            echo "    <submenu>$menu_path</submenu>"
            echo "    <unique-id>$unique_id</unique-id>"
            echo "    <command>bash &quot;$script_file&quot; %F</command>"
            echo "    <description></description>"
            echo "    <range></range>"
            echo "    <patterns>*</patterns>"
            echo "    <directories/>"
            echo "    <audio-files/>"
            echo "    <image-files/>"
            echo "    <text-files/>"
            echo "    <video-files/>"
            echo "    <other-files/>"
            echo "</action>"
        } >>"$menus_file"

    done < <(find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -print0 2>/dev/null | sort --zero-terminated)

    echo "</actions>" >>"$menus_file"

    # Then set up the keyboard shortcuts
    step_install_shortcuts_thunar "$accels_file"

    # Set proper permissions
    chmod 644 "$menus_file" "$accels_file"
}

step_install_menus() {
    # Install menus for specific file managers.
    echo "${R}[${G}-${R}]${G} Installing file manager menus...${NC}"

    case "$FILE_MANAGER" in
    "nautilus")
        # Nautilus uses scripts directly without desktop files
        # The scripts folder structure is sufficient for menu creation
        echo "${R}[${G}✓${R}]${G} Nautilus scripts installed (no additional menu setup required)${NC}"
        ;;
    "caja")
        # Caja uses scripts directly like Nautilus
        echo "${R}[${G}✓${R}]${G} Caja scripts installed (no additional menu setup required)${NC}"
        ;;
    "nemo")
        # Nemo uses scripts directly like Nautilus
        echo "${R}[${G}✓${R}]${G} Nemo scripts installed (no additional menu setup required)${NC}"
        ;;
    "pcmanfm-qt")
        step_install_menus_pcmanfm
        ;;
    "thunar")
        # First create menus, then shortcuts
        step_install_menus_thunar
        step_install_shortcuts_thunar "$HOME/.config/Thunar/accels.scm"
        ;;
    esac
}

step_install_scripts() {
    echo "${R}[${G}-${R}]${G} Removing previous scripts...${NC}"
    check_and_delete "$INSTALL_DIR"

    echo "${R}[${G}-${R}]${G} Installing new scripts...${NC}"
    check_and_create_directory "$INSTALL_DIR"

    # Copy the script files.
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR"

    # Set file permissions.
    echo "${R}[${G}-${R}]${G} Setting file permissions...${NC}"
    find -L "$INSTALL_DIR" -type f ! -path "*.git*" ! -exec chmod -x -- {} \;
    find -L "$INSTALL_DIR" -mindepth 2 -type f ! -path "*.git*" ! -path "*.assets*" -exec chmod +x -- {} \;
}

step_close_filemanager() {
    echo "${R}[${G}-${R}]${G} Closing the file manager to reload its configurations...${NC}"

    case "$FILE_MANAGER" in
    "nautilus")
        if pgrep -x "$FILE_MANAGER" &>/dev/null; then
            $FILE_MANAGER -q &>/dev/null || true &
            sleep 1
        else
            echo "${R}[${G}-${R}]${Y} No running instance of $FILE_MANAGER found.${NC}"
        fi
        ;;
    "caja" | "nemo" | "thunar")
        if pgrep -x "$FILE_MANAGER" &>/dev/null; then
            $FILE_MANAGER -q &>/dev/null || true &
        else
            echo "${R}[${G}-${R}]${Y} No running instance of $FILE_MANAGER found.${NC}"
        fi
        ;;
    "pcmanfm-qt")
        if pgrep -x "$FILE_MANAGER" &>/dev/null; then
            killall "$FILE_MANAGER" &>/dev/null || true &
        else
            echo "${R}[${G}-${R}]${Y} No running instance of $FILE_MANAGER found.${NC}"
        fi
        ;;
    *)
        print_failed "Unknown file manager: $FILE_MANAGER"
        ;;
    esac
}

check_files_copied_successfully() {
    local success=true
    local item

    for item in "$SCRIPT_DIR"/*; do
        local target="$INSTALL_DIR/$(basename "$item")"
        if [[ ! -e "$target" ]]; then
            echo "${R}[!] Missing: $target${NC}"
            success=false
        fi
    done

    if $success; then
        print_success "All files and folders have been copied successfully to $INSTALL_DIR"
    else
        print_failed "Some files or folders are missing in $INSTALL_DIR"
    fi
}

main() {
    echo "${R}[${G}*${R}]${G} Starting installation...${NC}"

    # First check and setup file manager
    setup_file_manager || {
        print_failed "Failed to setup file manager"
        exit 1
    }

    # Then install scripts to $INSTALL_DIR
    step_install_scripts || {
        print_failed "Failed to install scripts"
        exit 1
    }

    # After scripts are copied, install menus and shortcuts
    step_install_menus || {
        print_failed "Failed to install menus"
        exit 1
    }

    # Install keyboard shortcuts
    step_install_shortcuts || {
        print_failed "Failed to install shortcuts"
        exit 1
    }

    # Finally restart the file manager
    step_close_filemanager || {
        print_failed "Failed to restart file manager"
        exit 1
    }

    check_files_copied_successfully

    print_success "Installation completed successfully!"
    echo "${R}[${G}*${R}]${G} Please restart your file manager to see the changes${NC}"
}

check_termux
detact_package_manager
step_install_dependencies
main
