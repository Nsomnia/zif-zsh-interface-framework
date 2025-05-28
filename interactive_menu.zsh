#!/usr/bin/env zsh

# Load the zsh/curses module
# zmodload will return 0 on success, and non-zero on failure.
if ! zmodload zsh/curses; then
    print "Error: zsh/curses module could not be loaded." >&2
    print "Please ensure your Zsh version supports it and it's correctly installed." >&2
    exit 1
fi

# Initialize the curses environment
# This function sets up the terminal for curses-based applications.
if ! zcurses_initscr; then
    print "Error: Could not initialize curses environment (zcurses_initscr failed)." >&2
    exit 1
fi

# Enable colors
if zcurses_has_colors; then
    zcurses_start_color
    zcurses_init_pair 1 COLOR_WHITE COLOR_BLACK # Standard text
    zcurses_init_pair 2 COLOR_BLUE COLOR_BLACK  # Dialog borders, titles
    zcurses_init_pair 3 COLOR_BRIGHT_BLACK COLOR_BLACK # Shadow character (dimmed)
    zcurses_init_pair 4 COLOR_CYAN COLOR_BLACK  # Menu item indicators (submenu arrow)
    zcurses_init_pair 5 COLOR_YELLOW COLOR_BLACK # Focused elements (scrollbar thumb, input field text)
    zcurses_init_pair 6 COLOR_WHITE COLOR_BLUE # Focused button
    zcurses_init_pair 7 COLOR_GREEN COLOR_BLACK # File type indicator - File
    zcurses_init_pair 8 COLOR_MAGENTA COLOR_BLACK # File type indicator - Directory
else
    :
fi


zcurses_clear; zcurses_curs_set 0; zcurses_noecho; zcurses_keypad 1

# Define Key Code Constants
local KEY_UP=259; local KEY_DOWN=258; local KEY_ENTER_LF=10; local KEY_ENTER_CR=13
local KEY_Q_LOWER=113; local KEY_SPACEBAR=32; local KEY_ESC=27
local KEY_D_LOWER=100; local KEY_C_LOWER=99; local KEY_F_LOWER=102 # For File Picker Test via menu
local KEY_BACKSPACE=127; local KEY_LEFT_ARROW=260; local KEY_RIGHT_ARROW=261
local KEY_DC=330; local KEY_TAB=9
local ANIMATION_DELAY=10 # ms for dialog animation

# Scrollbar Constants (for main menu)
local scrollbar_col=40; local SCROLLBAR_TRACK_CHAR='│'; local SCROLLBAR_THUMB_CHAR='█'
local SCROLLBAR_UP_ARROW='▲'; local SCROLLBAR_DOWN_ARROW='▼'; local max_visible_items=5

# --- Menu Data Structures ---
local -a main_menu_items=("Network" "Appearance" "TestInputDialog" "TestConfirmDialog" "TestFilePickerDialog" "ExitProgram")
typeset -A menu_item_Network=(title="Network Settings" submenu="network_submenu_items")
typeset -A menu_item_Appearance=(title="Appearance Config" submenu="appearance_submenu_items")
typeset -A menu_item_TestInputDialog=(title="Test Input Dialog" action="test_input_dialog")
typeset -A menu_item_TestConfirmDialog=(title="Test Confirm Dialog" action="test_confirm_dialog")
typeset -A menu_item_TestFilePickerDialog=(title="Test File Picker" action="test_file_picker_dialog_action")
typeset -A menu_item_ExitProgram=(title="Exit Program")

local -a network_submenu_items=("Set_IP_Address" "Configure_DNS" "Back")
typeset -A menu_item_Set_IP_Address=(title="Set IP Address")
typeset -A menu_item_Configure_DNS=(title="Configure DNS")
typeset -A menu_item_Back=(title="Back to Main Menu")

local -a appearance_submenu_items=("Change_Theme" "Font_Size" "Back")
typeset -A menu_item_Change_Theme=(title="Change Theme")
typeset -A menu_item_Font_Size=(title="Font Size")

# --- Menu Stack and State ---
local -a menu_stack
typeset -A state_main_menu_items=(current_selection_idx=0 scroll_offset=0)
typeset -A state_network_submenu_items=(current_selection_idx=0 scroll_offset=0)
typeset -A state_appearance_submenu_items=(current_selection_idx=0 scroll_offset=0)

# --- Global Variables ---
local current_menu_array_name="main_menu_items"; local current_selection_idx=0; local scroll_offset=0
typeset -A multi_selected_states; local -a dialog_screen_backup_buffer
local global_input_string=""; local global_file_picker_result=""


# --- Dialog Drawing Functions ---
_draw_shadow() { local r=$1; local c=$2; local h=$3; local w=$4; local char='▒'; zcurses_attr_on "$(zcurses_color_pair 3)"; for i ({$((c+1))..$((c+w))}) zcurses_mvaddstr $((r+h)) $i "$char"; for i ({$((r+1))..$((r+h-1))}) zcurses_mvaddstr $i $((c+w)) "$char"; zcurses_attr_off "$(zcurses_color_pair 3)"; }

# _draw_box(start_row, start_col, height, width, title) - Animated
_draw_box() {
    local r_start=$1; local c_start=$2; local height=$3; local width=$4; local title=$5
    local r_end=$((r_start + height - 1)); local c_end=$((c_start + width - 1))

    # Apply border color
    zcurses_attr_on "$(zcurses_color_pair 2)"

    # Top-left corner
    zcurses_mvaddstr $r_start $c_start "┌"; zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY

    # Top border and title (animated part by part)
    local title_len=${#title}
    local title_display_start_col=$((c_start + (width - title_len) / 2))
    if (( title_display_start_col <= c_start )); then title_display_start_col=$((c_start + 1)); fi
    local title_actual_len=$title_len
    if (( title_display_start_col + title_len >= c_end )); then title_actual_len=$((c_end - title_display_start_col -1)); fi
    
    # Draw first part of top border
    for c in {$((c_start + 1))..$((title_display_start_col -1))}; do
        zcurses_mvaddstr $r_start $c "─"; 
    done
    if (( title_display_start_col > c_start + 1 )); then zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY; fi

    # Draw title (if any)
    if [[ -n "$title" && title_actual_len > 0 ]]; then
        zcurses_attr_on A_BOLD
        zcurses_mvaddstr $r_start $title_display_start_col "${title[1,$title_actual_len]}"
        zcurses_attr_off A_BOLD
        zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY
    fi

    # Draw rest of top border
    local top_border_title_end_col=$((title_display_start_col + title_actual_len))
    if ! [[ -n "$title" && title_actual_len > 0 ]]; then # Adjust if no title was drawn
        top_border_title_end_col=$((c_start + 1))
    fi
    for c in {$top_border_title_end_col..$((c_end - 1))}; do
        zcurses_mvaddstr $r_start $c "─";
    done
    if (( c_end -1 >= top_border_title_end_col )); then zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY; fi

    # Top-right corner
    zcurses_mvaddstr $r_start $c_end "┐"; zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY
    
    # Side borders (iteratively) and clear inner line
    zcurses_attr_off "$(zcurses_color_pair 2)" # Turn off border color for clearing
    zcurses_attr_on "$(zcurses_color_pair 1)"  # Set default color for inner area
    for r in {$((r_start + 1))..$((r_end - 1))}; do
        zcurses_attr_on "$(zcurses_color_pair 2)" # Border color for vertical lines
        zcurses_mvaddstr $r $c_start "│"; zcurses_mvaddstr $r $c_end "│"
        zcurses_attr_off "$(zcurses_color_pair 2)"
        
        # Clear inner line segment
        if (( width - 2 > 0 )); then zcurses_mvaddstr $r $((c_start + 1)) "$(printf '%*s' $((width - 2)) '')"; fi
        zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY
    done
    zcurses_attr_off "$(zcurses_color_pair 1)" # Turn off default color

    # Bottom border
    zcurses_attr_on "$(zcurses_color_pair 2)" # Border color
    zcurses_mvaddstr $r_end $c_start "└"; zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY # Bottom-left
    for c in {$((c_start + 1))..$((c_end - 1))}; do # Bottom line
        zcurses_mvaddstr $r_end $c "─";
    done
    if ((width > 2)); then zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY; fi
    zcurses_mvaddstr $r_end $c_end "┘"; zcurses_refresh; zcurses_delay_output $ANIMATION_DELAY # Bottom-right
    zcurses_attr_off "$(zcurses_color_pair 2)"
}

_draw_buttons() { local crs=$1; local ccs=$2; local cw=$3; local -n br="$4"; local fi=$5; local dih=$6; if (( ${#br[@]} == 0 )) return; local tbw=0; local -a dls=(); for l in "${br[@]}"; do if (( ${#dls[@]} == fi )); then dls+=("[ $l ]"); else dls+=("< $l >"); fi; tbw=$((tbw+${#dls[-1]}+2)); done; tbw=$((tbw-2)); local ccp=$((ccs+(cw-tbw)/2)); local brs=$((crs+dih-1)); for i ({1..${#dls[@]}}) { local dl="${dls[$i]}"; if ((i-1==fi)) { zcurses_attr_on "$(zcurses_color_pair 6)" A_BOLD; zcurses_mvaddstr $brs $ccp "$dl"; zcurses_attr_off "$(zcurses_color_pair 6)" A_BOLD; } else { zcurses_attr_on "$(zcurses_color_pair 1)"; zcurses_mvaddstr $brs $ccp "$dl"; zcurses_attr_off "$(zcurses_color_pair 1)"; } ccp=$((ccp+${#dl}+2)); }; }
_draw_message_content() { local cr=$1; local cc=$2; local cw=$3; local m="$4"; local dih=$5; local mr=$((cr+(dih-1-1)/2)); if ((dih<=2)) mr=$cr; local mmw=$((cw-2)); if ((${#m}>mmw && mmw>0)) m="${m[1,mmw]}"; zcurses_attr_on "$(zcurses_color_pair 1)"; zcurses_mvaddstr $mr $((cc+1)) "$m"; zcurses_attr_off "$(zcurses_color_pair 1)"; }

# --- File Picker Specific Functions ---
_file_picker_list_files() { local ptl="$1"; local -n lir="$2"; lir=(); local rp; rp=$(realpath -m "$ptl"); if [[ "$rp"!="/" && "$rp"==*/ ]] rp="${rp%/}"; if [[ "$rp"!="/" ]] lir+=(".."); local i; for i ("$rp"/*(N/)) lir+=("$(basename "$i")/"); for i ("$rp"/*(N.)) lir+=("$(basename "$i")"); }

# --- Core Dialog Interaction Handler ---
_handle_interactive_dialog() {
    local -n di_ref="$1" 
    local cr=${di_ref[content_start_row]}; local cc=${di_ref[content_start_col]}
    local dih=${di_ref[dialog_inner_height]}; local diw=${di_ref[dialog_inner_width]}
    local msg_txt="${di_ref[message]:-}"; local p_txt="${di_ref[prompt_text]:-}"
    local curr_in_val="${di_ref[initial_value]:-}"; local f_width=${di_ref[field_width]:-0}
    local btns_arr_name="${di_ref[buttons_array_name]:-}"; local -a btns_ref
    if [[ -n "$btns_arr_name" ]]; then eval "btns_ref=(\"\${(@P)btns_arr_name}\")"; fi
    local dialog_type="${di_ref[dialog_type]:-general}"

    local has_msg=$([[ -n "$msg_txt" ]]); local has_input=$([[ -n "$p_txt" ]])
    local curr_focus="message"; if $has_input; then curr_focus="input"; elif [[ "$dialog_type" == "file_picker" ]]; then curr_focus="file_list"; elif (( ${#btns_ref[@]} > 0 )); then curr_focus="buttons"; fi
    if ! $has_msg && ! $has_input && (( ${#btns_ref[@]} == 0 )) && [[ "$dialog_type" != "file_picker" ]]; then return 1; fi
    
    local focused_btn_idx=0; local cur_pos=${#curr_in_val}
    if (( f_width <= 0 && has_input )); then f_width=10; fi
    # Initial cursor state set before calling _handle_interactive_dialog by show_dialog

    local fp_current_path="${di_ref[initial_path]:-${PWD}}"
    local -a fp_list_display=()
    local fp_selected_idx=0; local fp_scroll_offset=0
    local fp_list_start_row=$((cr + 1)); local fp_list_height=$((dih - 2)); local fp_max_visible=$fp_list_height
    local num_fp_list_items=0

    if [[ "$dialog_type" == "file_picker" ]]; then
        _file_picker_list_files "$fp_current_path" fp_list_display
        num_fp_list_items=${#fp_list_display[@]}
    fi
    
    integer k_code
    # Initial draw of content before loop (buttons are drawn inside loop by _draw_buttons)
    if [[ "$curr_focus" == "input" ]]; then zcurses_curs_set 1; else zcurses_curs_set 0; fi

    zcurses_attr_on "$(zcurses_color_pair 1)" # Default dialog content bg
    if $has_msg && [[ "$dialog_type" != "file_picker" ]]; then _draw_message_content $cr $cc $diw "$msg_txt" $dih; fi
    if $has_input && [[ "$dialog_type" != "file_picker" ]]; then
        local f_start_r=$((cr + (dih-1-(${#btns_ref[@]}>0?1:0))/2)); if $has_msg; f_start_r=$((cr+2)); fi; if ((${#btns_ref[@]}>0)) && ! $has_msg; f_start_r=$((cr+1)); fi
        zcurses_mvaddstr $f_start_r $cc "$p_txt"; local f_disp_c=$((cc+${#p_txt}+1))
        zcurses_attr_on "$(zcurses_color_pair 5)"; zcurses_mvaddstr $f_start_r $f_disp_c "${(pl.$f_width.. .)}"; zcurses_mvaddstr $f_start_r $f_disp_c "$curr_in_val"; zcurses_attr_off "$(zcurses_color_pair 5)"
        if [[ "$curr_focus" == "input" ]]; then zcurses_move $f_start_r $((f_disp_c+cur_pos)); fi
    fi
    zcurses_attr_off "$(zcurses_color_pair 1)"
    if (( ${#btns_ref[@]} > 0 )); then _draw_buttons $cr $cc $diw "btns_ref" $focused_btn_idx $dih; fi
    # File picker list is drawn inside the loop as it's interactive

    while true; do
        # Redraw dynamic parts inside loop
        if [[ "$dialog_type" == "file_picker" ]]; then
            zcurses_attr_on "$(zcurses_color_pair 1)"
            local path_display_line="${(Mr.$((diw-2))...%)[Path: $fp_current_path]}"
            zcurses_mvaddstr $cr $((cc+1)) "$path_display_line"
            for i in {0..$((fp_max_visible-1))}; do
                local actual_idx=$((fp_scroll_offset + i)); local screen_row=$((fp_list_start_row + i))
                if (( actual_idx < num_fp_list_items )); then
                    local item_d="${fp_list_display[$((actual_idx+1))]}"
                    local list_item_color_pair=7; if [[ "$item_d" == */ || "$item_d" == ".." ]]; then list_item_color_pair=8; fi
                    zcurses_attr_on "$(zcurses_color_pair $list_item_color_pair)"
                    if (( actual_idx == fp_selected_idx && curr_focus == "file_list" )); then zcurses_attr_on A_REVERSE; fi
                    zcurses_mvaddstr $screen_row $((cc+1)) "${(Mr.$((diw-2))...%)[$item_d]}"
                    zcurses_attr_off A_REVERSE "$(zcurses_color_pair $list_item_color_pair)"
                else zcurses_mvaddstr $screen_row $((cc+1)) "${(pl.$((diw-2))... .)}"; fi
            done
            if (( num_fp_list_items > fp_max_visible )); then # File Picker Scrollbar
                local fp_sbar_col=$((cc + diw -1))
                for r_idx in {0..$((fp_max_visible-1))}; do zcurses_mvaddstr $((fp_list_start_row + r_idx)) $fp_sbar_col "$SCROLLBAR_TRACK_CHAR"; done
                local fp_thumb_h=$(( (fp_max_visible * fp_max_visible) / num_fp_list_items )); if ((fp_thumb_h==0)) fp_thumb_h=1; fi
                local fp_thumb_p=$(( (fp_scroll_offset * fp_max_visible) / num_fp_list_items )); if ((fp_thumb_p<0)) fp_thumb_p=0; fi
                if ((fp_thumb_p + fp_thumb_h > fp_max_visible)) fp_thumb_p=$((fp_max_visible - fp_thumb_h)); if ((fp_thumb_p<0)) fp_thumb_p=0; fi
                for t in {0..$((fp_thumb_h-1))}; do local ctr=$((fp_list_start_row + fp_thumb_p + t)); if ((ctr < fp_list_start_row + fp_max_visible)) { zcurses_attr_on "$(zcurses_color_pair 5)"; zcurses_mvaddstr $ctr $fp_sbar_col "$SCROLLBAR_THUMB_CHAR"; zcurses_attr_off "$(zcurses_color_pair 5)"; } done
            fi
            zcurses_attr_off "$(zcurses_color_pair 1)"
             _draw_buttons $cr $cc $diw "btns_ref" $focused_btn_idx $dih # Redraw buttons too
        elif $has_input; then # Redraw input field if it's the focus for cursor updates
             zcurses_attr_on "$(zcurses_color_pair 1)"
             local f_start_r=$((cr + (dih-1-(${#btns_ref[@]}>0?1:0))/2)); if $has_msg; f_start_r=$((cr+2)); fi; if ((${#btns_ref[@]}>0)) && ! $has_msg; f_start_r=$((cr+1)); fi
             local f_disp_c=$((cc+${#p_txt}+1))
             zcurses_attr_on "$(zcurses_color_pair 5)"; zcurses_mvaddstr $f_start_r $f_disp_c "${(pl.$f_width.. .)}"; zcurses_mvaddstr $f_start_r $f_disp_c "$curr_in_val"; zcurses_attr_off "$(zcurses_color_pair 5)"
             if [[ "$curr_focus" == "input" ]]; then zcurses_move $f_start_r $((f_disp_c+cur_pos)); fi
             zcurses_attr_off "$(zcurses_color_pair 1)"
             _draw_buttons $cr $cc $diw "btns_ref" $focused_btn_idx $dih # Redraw buttons too
        else # For message dialogs, buttons might need redraw if focus changes
            _draw_buttons $cr $cc $diw "btns_ref" $focused_btn_idx $dih
        fi
        zcurses_refresh; zcurses_getch k_code

        case $k_code in
            $KEY_TAB)
                if [[ "$dialog_type" == "file_picker" ]]; then
                    if (( ${#btns_ref[@]} > 0 )); then if [[ "$curr_focus" == "file_list" ]]; then curr_focus="buttons"; focused_btn_idx=0; zcurses_curs_set 0; else curr_focus="file_list"; zcurses_curs_set 0; fi; fi
                elif $has_input && (( ${#btns_ref[@]} > 0 )); then if [[ "$curr_focus" == "input" ]]; then curr_focus="buttons"; focused_btn_idx=0; zcurses_curs_set 0; else curr_focus="input"; zcurses_curs_set 1; fi
                elif !$has_input && (( ${#btns_ref[@]} > 1 )); then ((focused_btn_idx = (focused_btn_idx + 1) % ${#btns_ref[@]})); fi;;
            $KEY_ESC)
                if [[ "$dialog_type" == "file_picker" && "$curr_focus" == "file_list" ]]; then
                    if [[ "$fp_current_path" != "/" && "$fp_current_path" != "." && "$fp_current_path" != "" ]]; then fp_current_path="$(realpath -m "$fp_current_path/..")"; else return 1; fi 
                else global_input_string=""; di_ref[result_value]=""; return 1; fi 
                _file_picker_list_files "$fp_current_path" fp_list_display; num_fp_list_items=${#fp_list_display[@]}; fp_selected_idx=0; fp_scroll_offset=0; continue;;
            *) 
                if [[ "$dialog_type" == "file_picker" && "$curr_focus" == "file_list" ]]; then
                    case $k_code in
                        $KEY_UP) ((fp_selected_idx--)); if ((fp_selected_idx<0)) fp_selected_idx=$((num_fp_list_items-1)); fi; if ((fp_selected_idx < fp_scroll_offset)) fp_scroll_offset=$fp_selected_idx; fi; if ((fp_scroll_offset < 0)) fp_scroll_offset=0; fi;;
                        $KEY_DOWN) ((fp_selected_idx++)); if ((fp_selected_idx >= num_fp_list_items)) fp_selected_idx=0; fi; if ((fp_selected_idx >= fp_scroll_offset + fp_max_visible)) fp_scroll_offset=$((fp_selected_idx - fp_max_visible + 1)); fi; local m_fp_so=$((num_fp_list_items-fp_max_visible)); if ((m_fp_so<0)) m_fp_so=0; fi; if ((fp_scroll_offset>m_fp_so)) fp_scroll_offset=$m_fp_so; fi;;
                        $KEY_ENTER_LF | $KEY_ENTER_CR)
                            if (( num_fp_list_items == 0 )); then continue; fi 
                            local sel_item_disp="${fp_list_display[$((fp_selected_idx+1))]}"
                            local sel_basename="${sel_item_disp%/}" 
                            local new_path
                            if [[ "$sel_item_disp" == "../" ]]; then new_path=$(realpath -m "$fp_current_path/..");
                            elif [[ "$sel_item_disp" == */ ]]; then 
                                if [[ "$fp_current_path" == "/" ]]; then new_path="/$sel_basename"; else new_path="$fp_current_path/$sel_basename"; fi
                            else 
                                if [[ "$fp_current_path" == "/" ]]; then di_ref[result_value]="/$sel_basename"; else di_ref[result_value]="$fp_current_path/$sel_basename"; fi
                                curr_focus="buttons"; focused_btn_idx=0; for i ({1..${#btns_ref[@]}}) { if [[ "${btns_ref[$i]}" == "Select" ]]; then focused_btn_idx=$((i-1)); break; fi }; continue;
                            fi
                            if [[ -d "$new_path" ]]; then fp_current_path="$new_path"; else continue; fi
                            _file_picker_list_files "$fp_current_path" fp_list_display; num_fp_list_items=${#fp_list_display[@]}; fp_selected_idx=0; fp_scroll_offset=0;;
                    esac
                elif [[ "$curr_focus" == "input" ]] && $has_input; then
                    case $k_code in
                        $KEY_ENTER_LF|$KEY_ENTER_CR) if ((${#btns_ref[@]}>0)) { curr_focus="buttons"; focused_btn_idx=0; zcurses_curs_set 0; } else { global_input_string="$curr_in_val"; di_ref[result_value]="$curr_in_val"; return 0; } fi;;
                        $KEY_BACKSPACE) if ((cur_pos>0)) curr_in_val="${curr_in_val[1,$((cur_pos-1))]}${curr_in_val[$((cur_pos+1)),-1]}"; ((cur_pos--)); fi;;
                        $KEY_DC) if ((cur_pos<${#curr_in_val})) curr_in_val="${curr_in_val[1,$cur_pos]}${curr_in_val[$((cur_pos+2)),-1]}"; fi;;
                        $KEY_LEFT_ARROW) if ((cur_pos>0)) ((cur_pos--)); fi;;
                        $KEY_RIGHT_ARROW) if ((cur_pos<${#curr_in_val})) ((cur_pos++)); fi;;
                        *) if ((k_code>=32 && k_code<=126 && ${#curr_in_val}<f_width)) curr_in_val="${curr_in_val[1,$cur_pos]}$(printf \\$(printf '%03o' $k_code))${curr_in_val[$((cur_pos+1)),-1]}"; ((cur_pos++)); fi;;
                    esac
                elif [[ "$curr_focus" == "buttons" ]] && (( ${#btns_ref[@]} > 0 )); then
                    case $k_code in
                        $KEY_LEFT_ARROW) ((focused_btn_idx--)); if ((focused_btn_idx<0)) focused_btn_idx=$((${#btns_ref[@]}-1)); fi;;
                        $KEY_RIGHT_ARROW) ((focused_btn_idx++)); if ((focused_btn_idx >= ${#btns_ref[@]})) focused_btn_idx=0; fi;;
                        $KEY_ENTER_LF|$KEY_ENTER_CR) local sel_btn_lbl="${btns_ref[$((focused_btn_idx+1))]}"; if [[ "$sel_btn_lbl"=="OK"||"$sel_btn_lbl"=="Yes"||("$dialog_type"=="file_picker"&&"$sel_btn_lbl"=="Select") ]] { if $has_input { global_input_string="$curr_in_val"; di_ref[result_value]="$curr_in_val"; } if [[ "$dialog_type"=="file_picker" && -z "${di_ref[result_value]}" ]] continue; return 0; } elif [[ "$sel_btn_lbl"=="Cancel"||"$sel_btn_lbl"=="No" ]] { global_input_string=""; di_ref[result_value]=""; return 1; } else { di_ref[result_value]="$sel_btn_lbl"; return $((10+focused_btn_idx)); } fi;;
                    esac
                elif [[ "$curr_focus" == "message" ]]; then if ((k_code==$KEY_ENTER_LF || k_code==$KEY_ENTER_CR || k_code==$KEY_ESC)) return 1; fi;;
        esac
    done
}

_save_screen_region() { local r=$1; local c=$2; local h=$3; local w=$4; local -n b="$5"; b=(); for ro ({0..$((h-1))}) for co ({0..$((w-1))}) { local ra=$((r+ro)); local ca=$((c+co)); integer cav; zcurses_mvinch $ra $ca cav; b+=($cav); }; }
_restore_screen_region() { local r=$1; local c=$2; local h=$3; local w=$4; local -n b="$5"; local bi=1; for ro ({0..$((h-1))}) for co ({0..$((w-1))}) { local ra=$((r+ro)); local ca=$((c+co)); if ((bi<=${#b[@]})) zcurses_mvaddch $ra $ca ${b[$bi]}; ((bi++)); }; }

show_dialog() { 
    local -n dialog_info_ref="$1"
    local d_title="${dialog_info_ref[title]}"; local d_height=${dialog_info_ref[height]}; local d_width=${dialog_info_ref[width]}
    integer term_h term_w; zcurses_getmaxyx term_h term_w
    dialog_info_ref[start_row]=$(((term_h - d_height) / 2)); dialog_info_ref[start_col]=$(((term_w - d_width) / 2))
    dialog_info_ref[content_start_row]=$((dialog_info_ref[start_row] + 1)); dialog_info_ref[content_start_col]=$((dialog_info_ref[start_col] + 1))
    dialog_info_ref[dialog_inner_height]=$((d_height - 2)); dialog_info_ref[dialog_inner_width]=$((d_width - 2))

    _save_screen_region ${dialog_info_ref[start_row]} ${dialog_info_ref[start_col]} $((d_height + 1)) $((d_width + 1)) "dialog_screen_backup_buffer"
    _draw_shadow ${dialog_info_ref[start_row]} ${dialog_info_ref[start_col]} $d_height $d_width
    # _draw_box is now animated, call it. Content is drawn by _handle_interactive_dialog AFTER box is done.
    _draw_box ${dialog_info_ref[start_row]} ${dialog_info_ref[start_col]} $d_height $d_width "$d_title"
    
    local dialog_status=1; _handle_interactive_dialog "$1"; dialog_status=$?
    
    # Cursor visibility is managed by _handle_interactive_dialog, ensure it's off on exit.
    zcurses_curs_set 0 
    _restore_screen_region ${dialog_info_ref[start_row]} ${dialog_info_ref[start_col]} $((d_height + 1)) $((d_width + 1)) "dialog_screen_backup_buffer"
    zcurses_refresh; return $dialog_status
}

show_confirmation_dialog() { local t="$1"; local m="$2"; local -n btns="$3"; typeset -A cdi; cdi[title]="$t"; cdi[message]="$m"; cdi[buttons_array_name]="$3"; cdi[dialog_type]="confirm"; local msg_l=${#m}; local num_b=${#btns[@]}; local max_b_w=0; if ((num_b>0)) for bl in "${btns[@]}"; do if ((${#bl}>max_b_w)) max_b_w=${#bl}; done; fi; local btns_w=0; if ((num_b>0)) btns_w=$((num_b*(max_b_w+4)+(num_b-1)*2)); fi; cdi[width]=$((msg_l>btns_w?msg_l+4:btns_w+4)); if ((cdi[width]<20)) cdi[width]=20; fi; integer tc ZCOLS; zcurses_getmaxyx tr tc; if ((cdi[width]>tc-4)) cdi[width]=$((tc-4)); fi; cdi[height]=$((2+1+(num_b>0?1:0)+1)); show_dialog "cdi"; return $?; }
show_input_dialog() { local t="$1"; local p="$2"; local iv="$3"; local fw=$4; local -n btns="$5"; typeset -A idi; idi[title]="$t"; idi[prompt_text]="$p"; idi[initial_value]="$iv"; idi[field_width]=$fw; idi[buttons_array_name]="$5"; idi[dialog_type]="input"; local num_b=${#btns[@]}; local max_b_w=0; if ((num_b>0)) for bl in "${btns[@]}"; do if ((${#bl}>max_b_w)) max_b_w=${#bl}; done; fi; local btns_w=0; if ((num_b>0)) btns_w=$((num_b*(max_b_w+4)+(num_b-1)*2)); fi; local input_w=$((${#p}+1+fw)); idi[width]=$((input_w>btns_w?input_w+4:btns_w+4)); if ((idi[width]<30)) idi[width]=30; fi; integer tc ZCOLS; zcurses_getmaxyx tr tc; if ((idi[width]>tc-4)) idi[width]=$((tc-4)); fi; idi[height]=$((2+1+(num_b>0?1:0)+1)); show_dialog "idi"; return $?; }
show_file_picker_dialog() { local t="$1"; local ip="${2:-${PWD}}"; typeset -A fpd_info; fpd_info[title]="$t"; fpd_info[initial_path]="$ip"; fpd_info[dialog_type]="file_picker"; local -a fp_btns=("Select" "Cancel"); fpd_info[buttons_array_name]="fp_btns"; fpd_info[height]=15; fpd_info[width]=60; integer tc ZCOLS; zcurses_getmaxyx tr tc; if ((fpd_info[width]>tc-4)) fpd_info[width]=$((tc-4)); fi; show_dialog "fpd_info"; global_file_picker_result="${fpd_info[result_value]:-}"; return $?; }

push_menu() { local m="$1"; if [[ -z "$m" ]] return 1; eval "state_${current_menu_array_name}[current_selection_idx]=$current_selection_idx"; eval "state_${current_menu_array_name}[scroll_offset]=$scroll_offset"; menu_stack+=("$current_menu_array_name"); current_menu_array_name="$m"; if eval "[[ -n \${state_${current_menu_array_name}[current_selection_idx]+_} ]]"; then eval "current_selection_idx=\${state_${current_menu_array_name}[current_selection_idx]}"; eval "scroll_offset=\${state_${current_menu_array_name}[scroll_offset]}"; else eval "typeset -A state_${current_menu_array_name}=(current_selection_idx=0 scroll_offset=0)"; current_selection_idx=0; scroll_offset=0; fi; unset multi_selected_states; typeset -A multi_selected_states; return 0; }
pop_menu() { if (( ${#menu_stack[@]} == 0 )) return 1; current_menu_array_name="${menu_stack[-1]}"; menu_stack[-1]=(); eval "current_selection_idx=\${state_${current_menu_array_name}[current_selection_idx]}"; eval "scroll_offset=\${state_${current_menu_array_name}[scroll_offset]}"; unset multi_selected_states; typeset -A multi_selected_states; return 0; }

display_menu() { zcurses_clear; zcurses_attr_on "$(zcurses_color_pair 1)"; local -n cri="$current_menu_array_name"; local c=2; local nit=${#cri[@]}; for idi ({0..$((max_visible_items-1))}) { localaii=$((scroll_offset+idi)); local sr=$((idi+1)); if ((aii<nit)) { local in="${cri[$((aii+1))]}"; local tivn="menu_item_${in}[title]"; local it="${(P)tivn}"; if [[ -z "$it" ]] it="$in"; fi; local subr="${(P)menu_item_${in}[submenu]}"; local pfx=""; if [[ -n "$subr" ]] { zcurses_attr_on "$(zcurses_color_pair 4)" A_BOLD; pfx="→ "; zcurses_attr_off "$(zcurses_color_pair 4)" A_BOLD; } local idt; if [[ -n "${multi_selected_states[$aii]}" ]] idt="$pfx[x] $it"; else idt="$pfx[ ] $it"; fi; local miw=$((scrollbar_col-c-${#pfx}-3)); if ((${#it}>miw && miw>0)) { if [[ -n "${multi_selected_states[$aii]}" ]] idt="$pfx[x] ${it[1,miw]}…"; else idt="$pfx[ ] ${it[1,miw]}…"; fi; } if ((aii==current_selection_idx)) { zcurses_attr_on A_REVERSE; zcurses_mvaddstr $sr $c "$idt"; zcurses_attr_off A_REVERSE; } else { zcurses_attr_on "$(zcurses_color_pair 1)"; zcurses_mvaddstr $sr $c "$idt"; zcurses_attr_off "$(zcurses_color_pair 1)"; }} else zcurses_mvaddstr $sr $c "$(printf '%*s' $((scrollbar_col-c)) '')"; fi; }; zcurses_attr_on "$(zcurses_color_pair 1)"; zcurses_mvaddstr 0 $scrollbar_col "$SCROLLBAR_UP_ARROW"; for r ({1..$max_visible_items}) zcurses_mvaddstr $r $scrollbar_col "$SCROLLBAR_TRACK_CHAR"; zcurses_mvaddstr $((max_visible_items+1)) $scrollbar_col "$SCROLLBAR_DOWN_ARROW"; zcurses_attr_off "$(zcurses_color_pair 1)"; integer th=1; integer tp=0; if ((nit>0)) { if ((nit<=max_visible_items)) { th=$max_visible_items; tp=0; } else { th=$(((max_visible_items*max_visible_items)/nit)); if ((th==0)) th=1; fi; tp=$(((scroll_offset*max_visible_items)/nit)); if ((tp<0)) tp=0; fi; }} if ((tp+th>max_visible_items)) { tp=$((max_visible_items-th)); if ((tp<0)) tp=0; fi; } for t ({0..$((th-1))}) { local ctr=$((1+tp+t)); if ((ctr<=max_visible_items)) { zcurses_attr_on "$(zcurses_color_pair 5)"; zcurses_mvaddstr $ctr $scrollbar_col "$SCROLLBAR_THUMB_CHAR"; zcurses_attr_off "$(zcurses_color_pair 5)"; }}; zcurses_attr_on "$(zcurses_color_pair 1)"; integer termh termw; zcurses_getmaxyx termh termw; zcurses_mvaddstr $((termh-1)) 2 "Arrows: Nav | Space: Toggle | Enter: Action | Esc: Back | q: Quit"; zcurses_attr_off "$(zcurses_color_pair 1)"; }

eval "current_selection_idx=\${state_main_menu_items[current_selection_idx]}"; eval "scroll_offset=\${state_main_menu_items[scroll_offset]}"; display_menu

while true; do
    display_menu; zcurses_refresh; integer k_code; zcurses_getch k_code
    local -n cri="$current_menu_array_name"; local nit=${#cri[@]}
    case $k_code in
        $KEY_UP) ((current_selection_idx--)); if ((current_selection_idx<0)) current_selection_idx=$((nit-1)); fi; if ((current_selection_idx<scroll_offset)) scroll_offset=$current_selection_idx; fi; if ((scroll_offset<0)) scroll_offset=0; fi;;
        $KEY_DOWN) ((current_selection_idx++)); if ((current_selection_idx>=nit)) current_selection_idx=0; fi; if ((current_selection_idx>=scroll_offset+max_visible_items)) scroll_offset=$((current_selection_idx-max_visible_items+1)); fi; local mso=$((nit-max_visible_items)); if ((mso<0)) mso=0; fi; if ((scroll_offset>mso)) scroll_offset=$mso; fi;;
        $KEY_SPACEBAR) if [[ -n "${multi_selected_states[$current_selection_idx]}" ]] unset multi_selected_states[$current_selection_idx]; else multi_selected_states[$current_selection_idx]=1; fi;;
        $KEY_ENTER_LF | $KEY_ENTER_CR)
            local cin="${cri[$((current_selection_idx+1))]}"; local subr="${(P)menu_item_${cin}[submenu]}"; local actr="${(P)menu_item_${cin}[action]}"; local titr="${(P)menu_item_${cin}[title]}"
            if [[ -n "$subr" ]] push_menu "$subr"
            elif [[ "$actr" == "test_input_dialog" ]]; then local -a ib=("OK" "Cancel"); show_input_dialog "User Input" "Enter nickname:" "ZshFan" 25 "ib"; local is=$?; local rm; if ((is==0)) rm="OK: $global_input_string"; else rm="Cancel. Input: $global_input_string"; fi; zcurses_mvaddstr 0 0 "${(pl.70.. .)}"; zcurses_mvaddstr 0 0 "$rm"; zcurses_refresh; zcurses_napms 2000; global_input_string="";
            elif [[ "$actr" == "test_confirm_dialog" ]]; then local -a cb=("Yes" "No" "Maybe"); show_confirmation_dialog "Confirm Action" "Are you sure?" "cb"; local ch=$?; local cm; if ((ch==0)) cm="Confirmed (Yes/OK)"; elif ((ch==1)) cm="Cancelled (No/Cancel/Esc)"; elif ((ch==10)) cm="Chose: ${cb[1]}"; elif ((ch==11)) cm="Chose: ${cb[2]}"; elif ((ch==12)) cm="Chose: ${cb[3]}"; else cm="Unknown: $ch"; fi; zcurses_mvaddstr 1 0 "${(pl.70.. .)}"; zcurses_mvaddstr 1 0 "$cm"; zcurses_refresh; zcurses_napms 2000;
            elif [[ "$actr" == "test_file_picker_dialog_action" ]]; then show_file_picker_dialog "Select File" "$(pwd)"; local fs=$?; local fm; if ((fs==0 && -n "$global_file_picker_result" )) fm="Selected: $global_file_picker_result"; elif ((fs==0 && -z "$global_file_picker_result" )) fm="Selected: (selection cleared or no file chosen)"; else fm="File selection cancelled."; fi; zcurses_mvaddstr 2 0 "${(pl.70.. .)}"; zcurses_mvaddstr 2 0 "$fm"; zcurses_refresh; zcurses_napms 3000; global_file_picker_result="";
            elif [[ "$titr" == "Back to Main Menu" ]] pop_menu
            elif [[ "$cin" == "ExitProgram" ]] break;;
        $KEY_ESC) if ! pop_menu; then : ; fi;;
        $KEY_D_LOWER) local -a ib=("OK" "Cancel"); show_input_dialog "Direct Test Input" "Enter value:" "" 20 "ib"; local is=$?; local rm; if ((is==0)) rm="OK: $global_input_string"; else rm="Cancel. Input: $global_input_string"; fi; zcurses_mvaddstr 0 0 "${(pl.70.. .)}"; zcurses_mvaddstr 0 0 "$rm"; zcurses_refresh; zcurses_napms 2000; global_input_string="";;
        $KEY_C_LOWER) local -a cb=("Proceed" "Abort"); show_confirmation_dialog "Direct Test Confirm" "Confirm op?" "cb"; local ch=$?; local cm; if ((ch==0)) cm="Confirmed: ${cb[1]}"; elif ((ch==1)) cm="Cancelled: ${cb[2]}"; elif ((ch==10)) cm="Chose: ${cb[1]}"; elif ((ch==11)) cm="Chose: ${cb[2]}"; else cm="Unknown: $ch"; fi; zcurses_mvaddstr 1 0 "${(pl.70.. .)}"; zcurses_mvaddstr 1 0 "$cm"; zcurses_refresh; zcurses_napms 2000;;
        $KEY_F_LOWER) show_file_picker_dialog "Test From Key" "$(pwd)"; local fs=$?; local fm; if ((fs==0 && -n "$global_file_picker_result")) fm="Picked: $global_file_picker_result"; elif ((fs==0 && -z "$global_file_picker_result" )) fm="Selected: (selection cleared or no file chosen)"; else fm="Picker cancelled."; fi; zcurses_mvaddstr 2 0 "${(pl.70.. .)}"; zcurses_mvaddstr 2 0 "$fm"; zcurses_refresh; zcurses_napms 3000; global_file_picker_result="";;

        $KEY_Q_LOWER) break;;
    esac
done

zcurses_endwin
exit 0
