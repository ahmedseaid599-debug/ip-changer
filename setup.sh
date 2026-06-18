#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD_GREEN='\033[1;32m'
BOLD_CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===== MATRIX INTRO (FULL SCREEN RAIN) =====
matrix_intro() {
    clear
    cols=$(tput cols 2>/dev/null || echo 80)
    lines=$(tput lines 2>/dev/null || echo 24)

    # Hide cursor
    tput civis

    # Array of Matrix characters
    chars=(0 1 2 3 4 6 7 8 R S T U V W X Y Z \
            w x y z \
           ｱ ｲ ｳ ｴ ｵ ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ ﾐ ﾑ ﾒ ﾓ ﾔ ﾕ ﾖ \
           ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ヲ ン)

    # Initialize drops at random starting positions
    declare -a drop_pos
    declare -a drop_speed
    for ((i=0; i<cols; i++)); do
        drop_pos[$i]=$((RANDOM % lines))
        drop_speed[$i]=$((RANDOM % 3 + 1))
    done

    # Trap Ctrl+C to restore cursor
    trap 'tput cvvis; clear; exit 0' SIGINT SIGTERM

    end=$((SECONDS + 4))
    while [ $SECONDS -lt $end ]; do
        for ((col=0; col<cols; col++)); do
            # Draw the trail - multiple characters per column for depth
            for ((depth=0; depth<3; depth++)); do
                pos=$(( (drop_pos[$col] - depth + lines) % lines ))
                char_idx=$((RANDOM % ${#chars[@]}))
                
                if [ $depth -eq 0 ]; then
                    # Lead character - bright white
                    tput cup $pos $col 2>/dev/null
                    printf "${WHITE}${chars[$char_idx]}${NC}"
                elif [ $depth -eq 1 ]; then
                    # Second - bright green
                    tput cup $pos $col 2>/dev/null
                    printf "${BOLD_GREEN}${chars[$char_idx]}${NC}"
                else
                    # Trail - dim green
                    tput cup $pos $col 2>/dev/null
                    printf "${GREEN}${chars[$char_idx]}${NC}"
                fi
            done
            
            # Move drop down
            drop_pos[$col]=$(( (drop_pos[$col] + drop_speed[$col]) % lines ))
            
            # Random reset - send drop back to top
            if [ $((RANDOM % 20)) -eq 0 ]; then
                drop_pos[$col]=0
                drop_speed[$col]=$((RANDOM % 3 + 1))
            fi
        done
        sleep 0.05
    done

    # Restore cursor
    tput cvvis
    clear
}

matrix_intro
# ===== END MATRIX INTRO =====

echo -e "${BLUE}"
echo "TOR"
echo "  _____ _____     _____ _                                   "
echo " |_   _|  __ \   / ____| |                                  "
echo "   | | | |__) | | |    | |__   __ _ _ __   __ _  ___ _ __   "
echo "   | | |  ___/  | |    |  _ \ / _  |  _ \ / _  |/ _ \  __|  "
echo "  _| |_| |      | |____| | | | (_| | | | | (_| |  __/ |     "
echo " |_____|_|       \_____|_| |_|\__,_|_| |_|\__, |\___|_|     "
echo "                                           __/ |            "
echo "                                          |___/     V 1.0   "
echo -e "${NC}"
echo -e "${YELLOW}Author: 𝐌𝐞𝐥𝐢𝐨𝐝𝐚𝐬 𝐕𝐚𝐥𝐥𝐚𝐢𝐧 https://t.me/Heavenvoid ${NC}"
echo -e "${YELLOW}=========================================================${NC}\n"

set -e

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}❌ Unsupported Linux distribution!${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Detected Linux Distro: $DISTRO${NC}"

echo -e "${BLUE}[*] Installing required packages...${NC}"
case "$DISTRO" in
    arch|manjaro|blackarch)
        sudo pacman -Syu --noconfirm curl tor jq xxd
        TOR_GROUP="tor"
        ;;
    debian|ubuntu|kali|parrot)
        sudo apt update && sudo apt install -y curl tor jq xxd
        TOR_GROUP="debian-tor"
        ;;
    fedora)
        sudo dnf install -y curl tor jq xxd
        TOR_GROUP="tor"
        ;;
    opensuse*)
        sudo zypper install -y curl tor jq xxd
        TOR_GROUP="tor"
        ;;
    *)
        echo -e "${RED}❌ Unsupported distro. Please install curl, tor, jq, xxd manually.${NC}"
        exit 1
        ;;
esac

if ! getent group "$TOR_GROUP" >/dev/null; then
    echo -e "${BLUE}[*] Group '$TOR_GROUP' not found, creating it...${NC}"
    sudo groupadd "$TOR_GROUP"
fi

if ! groups "$USER" | grep -q " $TOR_GROUP"; then
    echo -e "${BLUE}[*] Adding user '$USER' to group '$TOR_GROUP'...${NC}"
    sudo usermod -aG "$TOR_GROUP" "$USER"
else
    echo -e "${GREEN}[✓] User '$USER' is already a member of group '$TOR_GROUP'.${NC}"
fi

echo -e "${BLUE}[*] Configuring Tor...${NC}"
TORRC_FILE="/etc/tor/torrc"
    NEEDS_UPDATE=0

    grep -q "^ControlPort 9051" "$TORRC_FILE" || NEEDS_UPDATE=1
    grep -q "^CookieAuthentication 1" "$TORRC_FILE" || NEEDS_UPDATE=1
    grep -q "^CookieAuthFileGroupReadable 1" "$TORRC_FILE" || NEEDS_UPDATE=1

    if [ "$NEEDS_UPDATE" -eq 1 ]; then
        echo -e "${BLUE}[*] Updating torrc with required ControlPort settings...${NC}"
        {
            echo ""
            echo "# Added by change-tor-ip automation script"
            echo "ControlPort 9051"
            echo "CookieAuthentication 1"
            echo "CookieAuthFileGroupReadable 1"
        } | sudo tee -a "$TORRC_FILE" > /dev/null
        sudo systemctl restart tor
    else
        echo -e "${GREEN}[✓] torrc already configured correctly. Skipping update.${NC}"
    fi
    
read -p "Enter Tor IP change interval (seconds, default 10): " TIME_INTERVAL
TIME_INTERVAL=${TIME_INTERVAL:-10}

echo -e "${BLUE}[*] Setting up systemd service with interval: $TIME_INTERVAL sec...${NC}"
sed -i "s/RestartSec=.*/RestartSec=$TIME_INTERVAL/" change-tor-ip.service

echo -e "${BLUE}[*] Deploying files...${NC}"
INSTALL_DIR="/home/$USER"
sudo cp change_tor_ip.sh "$INSTALL_DIR/"
sed -i "s#HOME#$INSTALL_DIR#g" "$INSTALL_DIR/change_tor_ip.sh"
sudo chmod +x "$INSTALL_DIR/change_tor_ip.sh"
sed -i "s|^ExecStart=.*|ExecStart=${INSTALL_DIR}/change_tor_ip.sh|" change-tor-ip.service
sudo cp change-tor-ip.service /etc/systemd/system/

echo -e "${BLUE}[*] Enabling and starting service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable --now change-tor-ip.service
sudo systemctl enable --now tor.service
echo -e "${GREEN}[✔] Deployment complete! Tor IP will change every $TIME_INTERVAL seconds.${NC}"
