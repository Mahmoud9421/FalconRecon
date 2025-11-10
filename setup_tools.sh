#!/usr/bin/env bash

# FalconEye Tool Installation Manager

TOOLS=("subfinder:~10MB" "httpx:~15MB" "gowitness:~25MB" "nmap:~30MB" "gobuster:~8MB" "katana:~12MB" "jq:~1MB" "wget:~1MB")
GO_TOOLS=("subfinder" "httpx" "gowitness" "katana")
WORDLISTS=(
    "/usr/share/wordlists/dirb/common.txt"
    "/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
    "/usr/share/seclists/Discovery/Web-Content/common.txt"
)

echo "Checking tools..."
echo ""

MISSING=()
for tool_info in "${TOOLS[@]}"; do
    tool="${tool_info%%:*}"
    size="${tool_info##*:}"
    
    command -v "$tool" &> /dev/null && echo "  ✓ $tool" || { echo "  ✗ $tool ($size)"; MISSING+=("$tool"); }
done

echo ""
echo "Checking wordlists..."
WORDLIST_FOUND=false
for wl in "${WORDLISTS[@]}"; do
    if [ -f "$wl" ]; then
        echo "  ✓ Wordlist found: $wl"
        WORDLIST_FOUND=true
        break
    fi
done

if [ "$WORDLIST_FOUND" = false ]; then
    echo "  ✗ No wordlist found"
    echo "    Recommended: sudo apt install wordlists seclists"
fi

echo ""

if [ ${#MISSING[@]} -eq 0 ] && [ "$WORDLIST_FOUND" = true ]; then
    echo "All tools ready."
    exit 0
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "${#MISSING[@]} tool(s) missing."
fi

if [ "$WORDLIST_FOUND" = false ]; then
    echo "Wordlists missing (needed for directory scanning)."
fi

read -p "Install missing items? [y/N]: " choice

if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo "Skipping installation."
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS."
    exit 1
fi

echo ""
echo "Installing for $OS..."
echo ""

install_go_tool() {
    local tool=$1
    local repo=$2
    
    if ! command -v "$tool" &> /dev/null; then
        echo "[*] Installing $tool..."
        go install -v "$repo@latest" 2>&1 | grep -v "go: downloading" | head -n 5
        command -v "$tool" &> /dev/null && echo "    ✓ $tool installed" || echo "    ✗ Failed to install $tool"
    fi
}

case $OS in
    ubuntu|debian|kali|parrot)
        echo "[*] Updating package list..."
        sudo apt update -y

        echo "[*] Installing required packages..."
     
        sudo apt install -y nmap jq wget golang gobuster wordlists seclists

        WORDLIST_FOUND=false
        for wl in "${WORDLISTS[@]}"; do
            if [ -f "$wl" ]; then
                WORDLIST_FOUND=true
                break
            fi
        done
        ;;
    fedora|rhel|centos|rocky|alma)
        for tool in nmap jq wget golang gobuster; do
            if ! rpm -q "$tool" &>/dev/null; then
                echo "[*] Installing $tool..."
                sudo dnf install -y "$tool" -q 2>/dev/null || sudo yum install -y "$tool" -q 2>/dev/null
                rpm -q "$tool" &>/dev/null && echo "    ✓ $tool installed" || echo "    ✗ Failed"
            fi
        done
        
        if [ "$WORDLIST_FOUND" = false ]; then
            echo "    Note: Install wordlists manually from SecLists GitHub"
        fi
        ;;
    arch|manjaro)
        for tool in nmap jq wget go gobuster; do
            if ! pacman -Q "$tool" &>/dev/null; then
                echo "[*] Installing $tool..."
                sudo pacman -S --noconfirm "$tool" 2>/dev/null && echo "    ✓ $tool installed" || echo "    ✗ Failed"
            fi
        done
        
        if [ "$WORDLIST_FOUND" = false ]; then
            echo "[*] Installing wordlists..."
            sudo pacman -S --noconfirm wordlists 2>/dev/null && echo "    ✓ wordlists installed" || echo "    ✗ Failed"
        fi
        ;;
    *)
        echo "Unsupported distro. Install manually."
        exit 1
        ;;
esac

if ! command -v go &> /dev/null; then
    echo ""
    echo "Go not found. Install Go manually for:"
    echo "  ${GO_TOOLS[*]}"
    echo ""
    echo "Visit: https://go.dev/doc/install"
    exit 1
fi

export PATH=$PATH:$(go env GOPATH)/bin
echo ""

# Install Go-based tools
for tool in "${GO_TOOLS[@]}"; do
    case $tool in
        subfinder) install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" ;;
        httpx) install_go_tool "httpx" "github.com/projectdiscovery/httpx/cmd/httpx" ;;
        gowitness) install_go_tool "gowitness" "github.com/sensepost/gowitness" ;;
        katana) install_go_tool "katana" "github.com/projectdiscovery/katana/cmd/katana" ;;
    esac
done

echo ""
echo "════════════════════════════════════════"
echo "Installation complete!"
echo "════════════════════════════════════════"
echo ""
echo "Note: Add $(go env GOPATH)/bin to your PATH:"
echo "  echo 'export PATH=\$PATH:$(go env GOPATH)/bin' >> ~/.bashrc"
echo "  source ~/.bashrc"
echo ""

exit 0