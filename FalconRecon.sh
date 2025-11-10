#!/usr/bin/env bash

COLORS=('\033[0;31m' '\033[0;32m' '\033[0;33m' '\033[0;34m' '\033[0;35m' '\033[0;36m')
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

get_color() { echo -e "${COLORS[$RANDOM % ${#COLORS[@]}]}"; }

FUNNY_QUOTES=(
    "This is taking longer than expected..."
    "Still working on it..."
    "Loading... grab some coffee..."
    "Processing data..."
    "Almost done... maybe..."
    "Scanning in progress..."
    "Please wait..."
)

show_banner() {
    clear
    echo -e "$(get_color)"
    cat << "EOF"
    ╔═════════════════════════════════════════════════╗
    ║   ███████╗ █████╗ ██╗      ██████╗ ██████╗      ║
    ║   ██╔════╝██╔══██╗██║     ██╔════╝██╔═══██╗     ║
    ║   █████╗  ███████║██║     ██║     ██║   ██║     ║
    ║   ██╔══╝  ██╔══██║██║     ██║     ██║   ██║     ║
    ║   ██║     ██║  ██║███████╗╚██████╗╚██████╔╝     ║
    ║   ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝      ║
    ║                                                 ║
    ║          🦅 FALCON RECON 🦅                     ║
    ║                                                 ║
    ║           Flying low, scanning high.            ║
    ║          Created by: Mahmoud Elshorbagy         ║
    ╚═════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "$(get_color)${FUNNY_QUOTES[$RANDOM % ${#FUNNY_QUOTES[@]}]}${NC}"
    echo ""
}

show_progress() {
    local pid=$1
    local counter=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -n "."; sleep 1
        ((counter++))
        [ $((counter % 10)) -eq 0 ] && echo -e "\n$(get_color)${FUNNY_QUOTES[$RANDOM % ${#FUNNY_QUOTES[@]}]}${NC}"
    done
    echo ""
}

get_wordlist() {
    local paths=("/usr/share/wordlists/dirb/common.txt" "/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt" "/usr/share/seclists/Discovery/Web-Content/common.txt")
    for p in "${paths[@]}"; do [ -f "$p" ] && { echo "$p"; return 0; }; done
    echo -e "$(get_color)Wordlist not found in standard locations${NC}" >&2
    return 1
}

show_banner

if [ -f "./setup_tools.sh" ]; then
    echo -e "$(get_color)⚚ Setting up required tools...${NC}"
    bash ./setup_tools.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Setup was not completed. Exiting Falcon Recon.${NC}"
        exit 1
    fi
    read -p "Setup complete. Press Enter to continue..."
    show_banner
fi

echo -e "$(get_color)𓆲 Enter your target domain:${NC}"
read -p "Domain: " TARGET
[ -z "$TARGET" ] && { echo -e "$(get_color)Error: No target specified. Exiting...${NC}"; exit 1; }

CLEAN_NAME=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|^www\.||' -e 's|/.*$||' -e 's|[^a-zA-Z0-9._-]|_|g')
RESULTS="results/${CLEAN_NAME}"
mkdir -p "$RESULTS"

echo ""; echo -e "$(get_color)𓆲 Target: $TARGET ${NC}"; echo -e "$(get_color)Results Directory: $RESULTS${NC}"; echo ""

enum_subdomains() {
    echo -e "$(get_color)𓅉 Enumerating subdomains...${NC}"
    DOMAIN=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|^www\.||' -e 's|/.*$||')
    command -v subfinder &> /dev/null && {
        subfinder -d "$DOMAIN" -silent -o "$RESULTS/subdomains.txt" 2>/dev/null &
        show_progress $!
        [ -s "$RESULTS/subdomains.txt" ] && echo -e "$(get_color)Found $(wc -l < "$RESULTS/subdomains.txt") subdomains${NC}" && echo -e "${GREEN}File created: $RESULTS/subdomains.txt${NC}" || echo -e "$(get_color)No subdomains found${NC}"
    } || echo -e "$(get_color)subfinder not found or not installed${NC}"
    echo ""
}

find_live() {
    [ ! -s "$RESULTS/subdomains.txt" ] && { echo -e "$(get_color)No subdomains file found. Run subdomain enumeration first.${NC}"; echo ""; return 1; }
    echo -e "$(get_color)🪽 Checking for live hosts...${NC}"
    command -v httpx &> /dev/null && command -v jq &> /dev/null && {
        httpx -l "$RESULTS/subdomains.txt" -json -silent -sc -title -tech-detect -nc -threads 50 2>/dev/null | tee >(jq -r '.url' > "$RESULTS/live.txt") > "$RESULTS/live_details.json"
        [ -s "$RESULTS/live.txt" ] && echo -e "$(get_color)$(wc -l < "$RESULTS/live.txt") live hosts discovered${NC}" && echo -e "${GREEN}Files created: $RESULTS/live.txt & $RESULTS/live_details.json${NC}" || echo -e "$(get_color)No live hosts found${NC}"
    } || echo -e "$(get_color)httpx or jq not found${NC}"
    echo ""
}

capture_screens() {
    [ ! -s "$RESULTS/live.txt" ] && { echo -e "$(get_color)No live hosts found. Run live host detection first.${NC}"; echo ""; return 1; }
    echo -e "$(get_color)𓅇 Capturing screenshots...${NC}"
    mkdir -p "$RESULTS/screens"
    command -v gowitness &> /dev/null && {
        gowitness scan file -f "$RESULTS/live.txt" -s "$RESULTS/screens/" --write-none --threads 5 &>/dev/null &
        show_progress $!
        echo -e "$(get_color)Screenshots completed${NC}"
        echo -e "${GREEN}Screenshots saved to: $RESULTS/screens/${NC}"
    } || echo -e "$(get_color)gowitness not found${NC}"
    echo ""
}

scan_ports() {
    echo -e "$(get_color)🦅 Scanning top 1000 ports...${NC}"
    SCAN_TARGET=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|^www\.||' -e 's|/.*$||')
    
    if ! command -v nmap &> /dev/null; then
        echo -e "$(get_color)nmap not found${NC}"
        echo ""
        return 1
    fi
    
    echo -e "$(get_color)Running nmap -Pn -sV... (this may take a moment)${NC}"
    nmap -Pn -sV -T4 --top-ports 1000 "$SCAN_TARGET" -oN "$RESULTS/ports.txt" &>/dev/null &
    show_progress $!
    
    if [ -s "$RESULTS/ports.txt" ] && grep -q "0 hosts up" "$RESULTS/ports.txt"; then
        echo -e "${RED}No hosts are up. Target may be invalid or unreachable.${NC}"
        echo -e "${RED}Check $RESULTS/ports.txt for details.${NC}"
    elif [ -s "$RESULTS/ports.txt" ] && grep -q " open " "$RESULTS/ports.txt"; then
        echo -e "$(get_color)Port scan complete. Open ports discovered!${NC}"
        echo -e "${GREEN}Report created: $RESULTS/ports.txt${NC}"
    elif [ -s "$RESULTS/ports.txt" ]; then
        echo -e "$(get_color)Port scan complete. No open ports found.${NC}"
        echo -e "${GREEN}Report created: $RESULTS/ports.txt${NC}"
    else
        echo -e "${RED}Port scan failed. No output generated.${NC}"
    fi
    echo ""
}

find_dirs() {
    local URL="$1"
    [ -z "$URL" ] && [ -s "$RESULTS/live.txt" ] && {
        echo -e "$(get_color)Select a target URL:${NC}";
        mapfile -t hosts < <(sort -u "$RESULTS/live.txt")
        select c in "${hosts[@]}"; do [ -n "$c" ] && { URL="$c"; break; }; done
    }
    [ -z "$URL" ] && { echo -e "$(get_color)No URL specified${NC}"; echo ""; return; }
    ! command -v gobuster &> /dev/null && { echo -e "$(get_color)gobuster not found${NC}"; echo ""; return 1; }

    WORDLIST=$(get_wordlist)
    [ -z "$WORDLIST" ] && {
        echo -e "$(get_color)No wordlist found. Enter custom wordlist path or press Enter to skip:${NC}"
        read -p "Path: " CUSTOM
        [ -n "$CUSTOM" ] && [ -f "$CUSTOM" ] && WORDLIST="$CUSTOM" || {
            echo -e "$(get_color)Skipping directory scan${NC}"; echo ""; return 1;
        }
    }

    echo -e "$(get_color)𓅂 Scanning directories for $URL${NC}"
    FNAME=$(echo "$URL" | sed -e 's|https\?://||' -e 's|[:/]|_|g')
    gobuster dir -u "$URL" -w "$WORDLIST" -t 50 -q -o "$RESULTS/dirs_${FNAME}.txt" 2>/dev/null &
    show_progress $!
    [ -s "$RESULTS/dirs_${FNAME}.txt" ] && echo -e "$(get_color)Found $(wc -l < "$RESULTS/dirs_${FNAME}.txt") directories${NC}" && echo -e "${GREEN}File created: $RESULTS/dirs_${FNAME}.txt${NC}" || echo -e "$(get_color)No directories found${NC}"
    echo ""
}

detect_tech() {
    [ ! -s "$RESULTS/live_details.json" ] && { echo -e "$(get_color)No live host data available${NC}"; echo ""; return 1; }
    echo -e "$(get_color)⚚ Detecting technologies...${NC}"
    jq -r 'select(.technologies != null and (.technologies | length) > 0) | "\(.url): \(.technologies | join(", "))"' "$RESULTS/live_details.json" > "$RESULTS/tech_summary.txt" 2>/dev/null
    sleep 1
    [ -s "$RESULTS/tech_summary.txt" ] && {
        echo -e "$(get_color)Technology stack detected:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$RESULTS/tech_summary.txt"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}File created: $RESULTS/tech_summary.txt${NC}"
    } || echo -e "$(get_color)No technologies detected${NC}"
    echo ""
}

crawl_site() {
    local URL="$1"
    [ -z "$URL" ] && [ -s "$RESULTS/live.txt" ] && {
        echo -e "$(get_color)Select a URL to crawl:${NC}"
        mapfile -t hosts < <(sort -u "$RESULTS/live.txt")
        select c in "${hosts[@]}"; do [ -n "$c" ] && { URL="$c"; break; }; done
    }
    [ -z "$URL" ] && { echo -e "$(get_color)No URL specified${NC}"; echo ""; return; }
    echo -e "$(get_color)𓅇 Crawling $URL${NC}"
    command -v katana &> /dev/null && {
        FNAME=$(echo "$URL" | sed -e 's|https\?://||' -e 's|[:/]|_|g')
        katana -u "$URL" -d 3 -o "$RESULTS/urls_${FNAME}.txt" -jc -kf all -silent -c 20 &>/dev/null &
        show_progress $!
        [ -s "$RESULTS/urls_${FNAME}.txt" ] && echo -e "$(get_color)Found $(wc -l < "$RESULTS/urls_${FNAME}.txt") URLs${NC}" && echo -e "${GREEN}File created: $RESULTS/urls_${FNAME}.txt${NC}" || echo -e "$(get_color)No URLs found${NC}"
    } || echo -e "$(get_color)katana not found${NC}"
    echo ""
}

full_scan() {
    echo -e "$(get_color)"; echo "╔════════════════════════════════════════╗"; echo "║   🦅 INITIATING FULL RECONNAISSANCE 🦅  ║"; echo "╚════════════════════════════════════════╝"; echo -e "${NC}"
    enum_subdomains
    find_live

    if [ -s "$RESULTS/live.txt" ]; then
        capture_screens &
        scan_ports &

        echo -e "$(get_color)𓅂 Scanning directories for all live hosts...${NC}"
        while IFS= read -r host; do
            find_dirs "$host" &
        done < "$RESULTS/live.txt"

        wait
        detect_tech
    else
        scan_ports
    fi

    echo -e "$(get_color)"; echo "╔════════════════════════════════════════╗"; echo "║   🦅 SCAN COMPLETE 🦅                   ║"; echo "╚════════════════════════════════════════╝"; echo -e "${NC}"
}

show_summary() {
    echo ""; echo -e "$(get_color)╔════════════════════════════════════════╗${NC}"; echo -e "$(get_color)║          RECONNAISSANCE SUMMARY         ║${NC}"; echo -e "$(get_color)╚════════════════════════════════════════╝${NC}"
    echo -e "$(get_color)𓆲 Target: $TARGET${NC}"; echo -e "$(get_color)Results: $RESULTS${NC}"; echo ""

    [ -f "$RESULTS/subdomains.txt" ] && echo -e "${GREEN}✓ Subdomains: $(wc -l < "$RESULTS/subdomains.txt")${NC}" || echo -e "${RED}✗ Subdomains not scanned${NC}"
    [ -f "$RESULTS/live.txt" ] && echo -e "${GREEN}✓ Live hosts: $(wc -l < "$RESULTS/live.txt")${NC}" || echo -e "${RED}✗ Live hosts not scanned${NC}"
    [ -d "$RESULTS/screens" ] && [ "$(find "$RESULTS/screens" -type f 2>/dev/null | wc -l)" -gt 0 ] && echo -e "${GREEN}✓ Screenshots: $(find "$RESULTS/screens" -type f 2>/dev/null | wc -l)${NC}" || echo -e "${RED}✗ Screenshots not taken${NC}"
    [ -f "$RESULTS/ports.txt" ] && echo -e "${GREEN}✓ Ports scanned${NC}" || echo -e "${RED}✗ Port scan not run${NC}"
    [ -n "$(find "$RESULTS" -name 'dirs_*.txt' -print -quit)" ] && echo -e "${GREEN}✓ Directories scanned${NC}" || echo -e "${RED}✗ Directory scan not run${NC}"
    [ -f "$RESULTS/tech_summary.txt" ] && echo -e "${GREEN}✓ Tech detected${NC}" || echo -e "${RED}✗ Tech detection not run${NC}"
    [ -n "$(find "$RESULTS" -name 'urls_*.txt' -print -quit)" ] && echo -e "${GREEN}✓ URLs crawled${NC}" || echo -e "${RED}✗ Web crawling not run${NC}"

    echo -e "$(get_color)╚════════════════════════════════════════╝${NC}"; echo ""
}

PS3=$(echo -e "\n$(get_color)𓅉 Select an option: ${NC}")
OPTIONS=("🦅 Full Auto Scan" "Hunt Subdomains" "Find Live Hosts" "Capture Screenshots" "Scan Ports" "Find Directories" "Detect Tech" "Crawl URLs" "⚚ View Summary" "Exit")

while true; do
    select opt in "${OPTIONS[@]}"; do
        case $opt in
            "🦅 Full Auto Scan") full_scan ;;
            "Hunt Subdomains") enum_subdomains ;;
            "Find Live Hosts") find_live ;;
            "Capture Screenshots") capture_screens ;;
            "Scan Ports") scan_ports ;;
            "Find Directories") find_dirs ;;
            "Detect Tech") detect_tech ;;
            "Crawl URLs") crawl_site ;;
            "⚚ View Summary") show_summary ;;
            "Exit") echo ""; echo -e "$(get_color)🦅 Exiting Falcon Recon. Goodbye! 🦅${NC}"; exit 0 ;;
            *) echo -e "$(get_color)Invalid option. Please try again.${NC}" ;;
        esac
        break
    done
done
