#!/bin/bash

SESSION_NAME="VoidSentinel-soc-cyber-dashboard"

NEON_CYAN='\033[38;5;51m'
NEON_PINK='\033[38;5;206m'
NEON_PURPLE='\033[38;5;141m'
NEON_GREEN='\033[38;5;118m'
NEON_YELLOW='\033[38;5;226m'
NEON_RED='\033[38;5;196m'
NEON_ORANGE='\033[38;5;208m'
NEON_MAGENTA='\033[38;5;201m'
DARK_GRAY='\033[38;5;240m'
MEDIUM_GRAY='\033[38;5;245m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
UNDERLINE='\033[4m'
NC='\033[0m'

# =========================================================
# 1. LOG COLORIZER
# =========================================================
cat << 'COLORIZER' > /tmp/cyber_colorizer.sh
#!/bin/bash
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\0' | sed 's/\r//g')
    line=$(echo "$line" | sed -E 's/([0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}[^ ]*)/\x1b[38;5;51m\1\x1b[0m/g')
    line=$(echo "$line" | sed -E 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/\x1b[38;5;206m\1\x1b[0m/g')
    line=$(echo "$line" | sed -E 's/(ERROR|error|failed|attack|invalid|CRITICAL)/\x1b[38;5;196m\1\x1b[0m/gi')
    line=$(echo "$line" | sed -E 's/(login|authenticated|success|accepted|open|Handling|connected)/\x1b[38;5;118m\1\x1b[0m/gi')
    line=$(echo "$line" | sed -E 's/(password|passwd|auth|secret|key)/\x1b[38;5;226m\1\x1b[0m/gi')
    line=$(echo "$line" | sed -E 's/(DEBUG|INFO|WARNING|WARN)/\x1b[38;5;141m\1\x1b[0m/g')
    line=$(echo "$line" | sed -E 's/:(22|23|80|443|8080|3306|5432)/\x1b[38;5;208m:\1\x1b[0m/g')
    line=$(echo "$line" | sed -E 's/(scraping|crawling|bot|spider)/\x1b[38;5;118m\1\x1b[0m/gi')
    line=$(echo "$line" | sed -E 's/(https?:\/\/[^ ]+)/\x1b[38;5;141m\x1b[4m\1\x1b[0m/gi')
    echo -e "$line"
done
COLORIZER
chmod +x /tmp/cyber_colorizer.sh

# =========================================================
# 2. STATS PANEL – mit fließendem LIVE FEED
# =========================================================
cat << 'STATS' > /tmp/cyber_stats.sh
#!/bin/bash

NEON_CYAN='\033[38;5;51m'
NEON_PINK='\033[38;5;206m'
NEON_PURPLE='\033[38;5;141m'
NEON_GREEN='\033[38;5;118m'
NEON_YELLOW='\033[38;5;226m'
NEON_RED='\033[38;5;196m'
NEON_ORANGE='\033[38;5;208m'
NEON_MAGENTA='\033[38;5;201m'
DARK_GRAY='\033[38;5;240m'
MEDIUM_GRAY='\033[38;5;245m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
UNDERLINE='\033[4m'
NC='\033[0m'

cleanup() {
    echo -ne "\033[?25h\033[0m"
    exit 0
}
trap cleanup EXIT INT TERM

W=68

pad() {
    local text="$1"
    local width="$2"
    local clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#clean}
    local diff=$((width - len))
    if [ $diff -gt 0 ]; then
        local spaces=""
        for ((i=0; i<diff; i++)); do spaces+=" "; done
        echo -ne "${text}${spaces}"
    else
        echo -ne "$text"
    fi
}

get_star_color() {
    local idx=$1
    local colors=("$NEON_YELLOW" "$NEON_PINK" "$NEON_CYAN" "$NEON_MAGENTA" "$NEON_GREEN" "$NEON_ORANGE")
    echo "${colors[$((idx % 6))]}"
}

STAR_SYMBS=("✦" "✧" "★" "☆" "✶" "✷")
get_star() {
    local idx=$1
    local symb="${STAR_SYMBS[$((idx % 6))]}"
    local color=$(get_star_color $idx)
    echo "${color}${BOLD}${symb}${NC}"
}

SPINNERS=("◐" "◓" "◑" "◒")
get_spinner() {
    local idx=$1
    echo "${NEON_MAGENTA}${BOLD}${SPINNERS[$((idx % 4))]}${NC}"
}

draw_bar() {
    local value=$1 max=$2 width=14
    [ "$max" -eq 0 ] && max=1
    [ "$value" -gt "$max" ] && value=$max
    local filled=$(( value * width / max ))
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do
        if [ $i -lt $((filled / 3)) ]; then bar+="${NEON_GREEN}█${NC}"
        elif [ $i -lt $((filled * 2 / 3)) ]; then bar+="${NEON_YELLOW}█${NC}"
        else bar+="${NEON_RED}█${NC}"; fi
    done
    for ((i=0; i<empty; i++)); do bar+="${DARK_GRAY}░${NC}"; done
    echo -ne "$bar"
}

clear
echo -ne "\033[?25l"

ITERATION=0
LAST_UPDATE=0
FEED_HISTORY=()
MAX_FEED=8  # Anzahl der Zeilen im Feed

# Statistiken
C_TOTAL=0; C_IPS=0; H_TOTAL=0; H_IPS=0; K_TOTAL=0
C_TOP_IP=""; C_TOP_IP_COUNT=0
H_TOP_IP=""; H_TOP_IP_COUNT=0
K_TOP_IP=""; K_TOP_IP_COUNT=0

LAN_IP=$(hostname -I | awk '{print $1}')
WAN_IP=$(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo "OFFLINE")

while true; do
    ITERATION=$((ITERATION + 1))
    CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_UPDATE)) -ge 2 ]; then
        COWRIE_LOGS=$(timeout 2 docker logs --tail 1000 cowrie 2>&1 | tr -d '\0' || echo "")
        HONEY_DATA=$(timeout 2 docker logs --tail 1000 honeytrap 2>&1 | tr -d '\0' || echo "")
        KRAWL_LOGS=$(timeout 2 docker logs --tail 1000 krawl 2>&1 | tr -d '\0' || echo "")
        
        # Cowrie
        if [ -n "$COWRIE_LOGS" ]; then
            C_TOTAL=$(echo "$COWRIE_LOGS" | grep -ci "login attempt\|New connection" 2>/dev/null || echo "0")
            C_IPS=$(echo "$COWRIE_LOGS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort -u 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            C_TOP_IP=$(echo "$COWRIE_LOGS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $2}')
            C_TOP_IP_COUNT=$(echo "$COWRIE_LOGS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $1}')
            [ -z "$C_TOP_IP" ] && C_TOP_IP_COUNT=0
        fi
        
        # Honeytrap
        if [ -n "$HONEY_DATA" ]; then
            H_TOTAL=$(echo "$HONEY_DATA" | wc -l 2>/dev/null | tr -d ' ' || echo "0")
            H_IPS=$(echo "$HONEY_DATA" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort -u 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            H_TOP_IP=$(echo "$HONEY_DATA" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $2}')
            H_TOP_IP_COUNT=$(echo "$HONEY_DATA" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $1}')
            [ -z "$H_TOP_IP" ] && H_TOP_IP_COUNT=0
        fi
        
        # Krawl
        if [ -n "$KRAWL_LOGS" ]; then
            K_TOTAL=$(echo "$KRAWL_LOGS" | grep -ci "request\|fetch\|scraping\|GET\|POST" 2>/dev/null || echo "0")
            K_TOP_IP=$(echo "$KRAWL_LOGS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $2}')
            K_TOP_IP_COUNT=$(echo "$KRAWL_LOGS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null | sort 2>/dev/null | uniq -c 2>/dev/null | sort -nr 2>/dev/null | head -n1 | awk '{print $1}')
            [ -z "$K_TOP_IP" ] && K_TOP_IP_COUNT=0
        fi
        
        # NEUE FEED-MELDUNGEN GENERIEREN (mit Zeitstempel)
        TIMESTAMP=$(date '+%H:%M:%S')
        FEED_MSG=""
        
        # Cowrie Meldung
        if [ "$C_TOP_IP_COUNT" -gt 3 ] && [ -n "$C_TOP_IP" ]; then
            FEED_MSG="${NEON_RED}🚨 [${TIMESTAMP}] Cowrie: Massive attack from ${NEON_YELLOW}${C_TOP_IP}${NC} (${C_TOP_IP_COUNT}x)"
        elif [ "$C_TOP_IP_COUNT" -gt 0 ] && [ -n "$C_TOP_IP" ]; then
            FEED_MSG="${NEON_PINK}🔍 [${TIMESTAMP}] Cowrie: Top attacker ${NEON_YELLOW}${C_TOP_IP}${NC} (${C_TOP_IP_COUNT}x)"
        else
            FEED_MSG="${DARK_GRAY}⏳ [${TIMESTAMP}] Cowrie: No attacks (${C_TOTAL} Events)"
        fi
        FEED_HISTORY+=("$FEED_MSG")
        
        # Honeytrap Meldung
        if [ "$H_TOP_IP_COUNT" -gt 3 ] && [ -n "$H_TOP_IP" ]; then
            FEED_MSG="${NEON_ORANGE}🔥 [${TIMESTAMP}] Honeytrap: Attack wave from ${NEON_YELLOW}${H_TOP_IP}${NC} (${H_TOP_IP_COUNT}x)"
        elif [ "$H_TOP_IP_COUNT" -gt 0 ] && [ -n "$H_TOP_IP" ]; then
            FEED_MSG="${NEON_PURPLE}🕸️ [${TIMESTAMP}] Honeytrap: Top attacker ${NEON_YELLOW}${H_TOP_IP}${NC} (${H_TOP_IP_COUNT}x)"
        else
            FEED_MSG="${DARK_GRAY}⏳ [${TIMESTAMP}] Honeytrap: No activity (${H_TOTAL} Events)"
        fi
        FEED_HISTORY+=("$FEED_MSG")
        
        # Krawl Meldung
        if [ "$K_TOP_IP_COUNT" -gt 2 ] && [ -n "$K_TOP_IP" ]; then
            FEED_MSG="${NEON_MAGENTA}🤖 [${TIMESTAMP}] Krawl: High activity from ${NEON_YELLOW}${K_TOP_IP}${NC} (${K_TOP_IP_COUNT}x)"
        elif [ "$K_TOP_IP_COUNT" -gt 0 ] && [ -n "$K_TOP_IP" ]; then
            FEED_MSG="${NEON_MAGENTA}🌐 [${TIMESTAMP}] Krawl: Requests from ${NEON_YELLOW}${K_TOP_IP}${NC}"
        else
            FEED_MSG="${DARK_GRAY}⏳ [${TIMESTAMP}] Krawl: No activity (${K_TOTAL} Requests)"
        fi
        FEED_HISTORY+=("$FEED_MSG")
        
        # Feed-Historie auf MAX_FEED begrenzen
        if [ ${#FEED_HISTORY[@]} -gt $MAX_FEED ]; then
            FEED_HISTORY=("${FEED_HISTORY[@]: -$MAX_FEED}")
        fi
        
        LAST_UPDATE=$CURRENT_TIME
    fi
    
    # Animation
    STAR1=$(get_star $ITERATION)
    STAR2=$(get_star $((ITERATION + 2)))
    STAR3=$(get_star $((ITERATION + 4)))
    STAR4=$(get_star $((ITERATION + 1)))
    SPINNER=$(get_spinner $ITERATION)
    
    if [ $((ITERATION % 2)) -eq 0 ]; then
        THREAT_LED="${NEON_RED}${BOLD}⚠ ${NC}"
        STATUS_LED="${NEON_GREEN}${BOLD}● ${NC}"
    else
        THREAT_LED="${DARK_GRAY}⚠ ${NC}"
        STATUS_LED="${DARK_GRAY}● ${NC}"
    fi
    
    SCAN_POS=$((ITERATION % 40))
    SCAN_BAR=""
    for ((i=0; i<40; i++)); do
        if [ $i -eq $SCAN_POS ]; then SCAN_BAR+="${NEON_CYAN}${BOLD}█${NC}"
        elif [ $(( (i + ITERATION) % 8 )) -eq 0 ]; then SCAN_BAR+="${NEON_GREEN}$((RANDOM % 10))${NC}"
        else SCAN_BAR+="${DARK_GRAY}░${NC}"; fi
    done
    
    TIME_NOW=$(date '+%H:%M:%S')
    
    # ===== SYSTEM STATS =====
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    [ -z "$CPU" ] && CPU=0
    RAM_USED=$(free -m | awk 'NR==2{print $3}')
    RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
    UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime)
    UPTIME_DAYS=$((UPTIME_SEC / 86400))
    UPTIME_HOURS=$(( (UPTIME_SEC % 86400) / 3600 ))
    UPTIME_MINS=$(( (UPTIME_SEC % 3600) / 60 ))
    UPTIME_STR="${UPTIME_DAYS}d ${UPTIME_HOURS}h ${UPTIME_MINS}m"
    
    # ===== FRAME AUFBAUEN =====
    FRAME=""
    FRAME+="\n"
    FRAME+=" $(pad "${NEON_CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_CYAN}${BOLD}║${NC} ${NEON_PINK}${BOLD}█▓▒░${NC} ${NEON_MAGENTA}${BOLD}GLOBAL SECURITY OPERATIONS CENTER${NC} ${NEON_PINK}${BOLD}░▒▓█${NC} ${NEON_CYAN}${BOLD}║${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== DARK QUOTE IN ONE LINE =====
    FRAME+=" $(pad "${NEON_RED}${BOLD}┌─[ ☠️ Hack the Planet! ☠️ ]───────────────────────────────────┐${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_RED}${BOLD}│${NC} ${NEON_YELLOW}“The devil whispered: You are not strong enough... But I am the storm.” ${NEON_RED}🔥${NC} ${NEON_RED}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_RED}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    SYS_LINE=" ${NEON_CYAN}LAN:${NC} ${BOLD}${LAN_IP}${NC} ${MEDIUM_GRAY}│${NC} ${NEON_PINK}WAN:${NC} ${BOLD}${WAN_IP}${NC} ${MEDIUM_GRAY}│${NC} ${NEON_ORANGE}${TIME_NOW}${NC}"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}┌─[ 🖥 SYSTEM ]─────────────────────────────────────────────┐${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}│${NC}${SYS_LINE}${NEON_GREEN}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    THREAT_LINE=" ${THREAT_LED}${NEON_RED}${BLINK}ELEVATED${NC} ${MEDIUM_GRAY}│${NC} ${NEON_CYAN}ATTACKS:${NC} ${BOLD}${NEON_RED}DETECTED${NC}"
    FRAME+=" $(pad "${NEON_RED}${BOLD}┌─[ ⚡ THREAT ]─────────────────────────────────────────────┐${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_RED}${BOLD}│${NC}${THREAT_LINE}${NEON_RED}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_RED}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== COWRIE (kompakt) =====
    FRAME+=" $(pad "${NEON_PINK}${BOLD}╔══${NC}${STAR1}${NEON_PINK}${BOLD}═[ 🛡  COWRIE ]═${STAR2}${NEON_PINK}${BOLD}══╗${NC}" $W)\n"
    COW_STAT="  ${NEON_YELLOW}Events:${NC} ${BOLD}${C_TOTAL}${NC} ${MEDIUM_GRAY}│${NC} ${NEON_YELLOW}IPs:${NC} ${BOLD}${C_IPS}${NC}"
    FRAME+=" $(pad "${COW_STAT}" $W)\n"
    if [ -n "$C_TOP_IP" ] && [ "$C_TOP_IP_COUNT" -gt 0 ]; then
        FRAME+=" $(pad "  ${NEON_PINK}Top:${NC} ${C_TOP_IP} (${C_TOP_IP_COUNT}x)" $W)\n"
    else
        FRAME+=" $(pad "  ${DARK_GRAY}No attacks" $W)\n"
    fi
    FRAME+=" $(pad "${NEON_PINK}${BOLD}╚═══════════════════════════════════════════════════════════════════╝${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== HONEYTRAP (kompakt) =====
    FRAME+=" $(pad "${NEON_PURPLE}${BOLD}══${STAR3}${NEON_PURPLE}${BOLD}═[ 🕸  HONEYTRAP ]═${STAR4}${NEON_PURPLE}${BOLD}══╗${NC}" $W)\n"
    HONEY_STAT="  ${NEON_YELLOW}Events:${NC} ${BOLD}${H_TOTAL}${NC} ${MEDIUM_GRAY}│${NC} ${NEON_YELLOW}IPs:${NC} ${BOLD}${H_IPS}${NC}"
    FRAME+=" $(pad "${HONEY_STAT}" $W)\n"
    if [ -n "$H_TOP_IP" ] && [ "$H_TOP_IP_COUNT" -gt 0 ]; then
        FRAME+=" $(pad "  ${NEON_PURPLE}Top:${NC} ${H_TOP_IP} (${H_TOP_IP_COUNT}x)" $W)\n"
    else
        FRAME+=" $(pad "  ${DARK_GRAY}No activity" $W)\n"
    fi
    FRAME+=" $(pad "${NEON_PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════════╝${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== GESAMTSTATISTIK (TOTAL) =====
    TOTAL_ATTACKS=$((C_TOTAL + H_TOTAL + K_TOTAL))
    [ $TOTAL_ATTACKS -eq 0 ] && TOTAL_ATTACKS=1
    C_PERC=$((C_TOTAL * 100 / TOTAL_ATTACKS))
    H_PERC=$((H_TOTAL * 100 / TOTAL_ATTACKS))
    K_PERC=$((K_TOTAL * 100 / TOTAL_ATTACKS))
    
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}┌─[ 📊 TOTAL ]─────────────────────────────────────────────┐${NC}" $W)\n"
    STAT_LINE1=" ${NEON_YELLOW}Total: ${NEON_GREEN}${BOLD}${TOTAL_ATTACKS}${NC}"
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}│${NC}${STAT_LINE1}${NEON_YELLOW}${BOLD}│${NC}" $W)\n"
    COW_BAR=$(draw_bar $C_PERC 100)
    STAT_LINE2=" ${NEON_PINK}Cowrie:${NC} ${COW_BAR} ${NEON_CYAN}${C_PERC}%${NC} (${C_TOTAL})"
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}│${NC}${STAT_LINE2}${NEON_YELLOW}${BOLD}│${NC}" $W)\n"
    HTR_BAR=$(draw_bar $H_PERC 100)
    STAT_LINE3=" ${NEON_PURPLE}Honeytrap:${NC} ${HTR_BAR} ${NEON_CYAN}${H_PERC}%${NC} (${H_TOTAL})"
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}│${NC}${STAT_LINE3}${NEON_YELLOW}${BOLD}│${NC}" $W)\n"
    KRL_BAR=$(draw_bar $K_PERC 100)
    STAT_LINE4=" ${NEON_MAGENTA}Krawl:${NC} ${KRL_BAR} ${NEON_CYAN}${K_PERC}%${NC} (${K_TOTAL})"
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}│${NC}${STAT_LINE4}${NEON_YELLOW}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_YELLOW}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== FLIESSENDER LIVE THREAT FEED (8 Zeilen) =====
    FRAME+=" $(pad "${NEON_RED}${BOLD}┌─[ 🔴 LIVE THREAT FEED ]────────────────────────────────────┐${NC}" $W)\n"
    # Aktuelle Feed-Historie anzeigen (max 8 Zeilen)
    for ((i=0; i<${#FEED_HISTORY[@]}; i++)); do
        line="${FEED_HISTORY[$i]}"
        FRAME+=" $(pad "${NEON_RED}${BOLD}│${NC} ${line}${NEON_RED}${BOLD}│${NC}" $W)\n"
    done
    # Leere Zeilen auffüllen, falls weniger als MAX_FEED
    for ((i=${#FEED_HISTORY[@]}; i<$MAX_FEED; i++)); do
        FRAME+=" $(pad "${NEON_RED}${BOLD}│${NC} ${DARK_GRAY}─${NC}${NEON_RED}${BOLD}│${NC}" $W)\n"
    done
    FRAME+=" $(pad "${NEON_RED}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    # ===== SYSTEM MONITOR =====
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}┌─[ 💻 SYSTEM ]────────────────────────────────────────────┐${NC}" $W)\n"
    SYS_LINE1=" ${NEON_YELLOW}CPU:${NC} ${NEON_GREEN}${CPU}%${NC}  ${NEON_YELLOW}RAM:${NC} ${NEON_PINK}${RAM_USED}MiB / ${RAM_TOTAL}MiB (${RAM_PERCENT}%)${NC}"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}│${NC}${SYS_LINE1}${NEON_GREEN}${BOLD}│${NC}" $W)\n"
    SYS_LINE2=" ${NEON_YELLOW}UPTIME:${NC} ${NEON_ORANGE}${UPTIME_STR}${NC}"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}│${NC}${SYS_LINE2}${NEON_GREEN}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+="\n"
    
    # Status Footer
    STAT_LINE=" ${STATUS_LED}${NEON_GREEN}${BOLD}ONLINE${NC} ${MEDIUM_GRAY}│${NC} ${NEON_CYAN}Update:${NC} ${BOLD}${TIME_NOW}${NC}"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}┌─[ 💚 STATUS ]─────────────────────────────────────────────┐${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}│${NC}${STAT_LINE}${NEON_GREEN}${BOLD}│${NC}" $W)\n"
    FRAME+=" $(pad "${NEON_GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}" $W)\n"
    FRAME+=" $(pad " ${NEON_CYAN}🔄 SCAN:${NC} ${SCAN_BAR}" $W)\n"
    
    echo -ne "\033[H${FRAME}"
    sleep 1
done
STATS
chmod +x /tmp/cyber_stats.sh

# =========================================================
# 3. TMUX SESSION – unverändert
# =========================================================
tmux kill-session -t $SESSION_NAME 2>/dev/null

tmux new-session -d -s $SESSION_NAME -x $(tput cols) -y $(tput lines)

tmux split-window -h -t $SESSION_NAME -l 55%
tmux split-window -v -t $SESSION_NAME:0.1 -l 50%
tmux split-window -h -t $SESSION_NAME:0.2 -l 50%

tmux send-keys -t $SESSION_NAME:0.0 '/tmp/cyber_stats.sh' C-m
tmux send-keys -t $SESSION_NAME:0.1 'docker logs --tail 0 -f cowrie 2>&1 | stdbuf -oL /tmp/cyber_colorizer.sh' C-m
tmux send-keys -t $SESSION_NAME:0.2 'docker logs --tail 0 -f honeytrap 2>&1 | stdbuf -oL /tmp/cyber_colorizer.sh' C-m
tmux send-keys -t $SESSION_NAME:0.3 'docker logs --tail 0 -f krawl 2>&1 | stdbuf -oL /tmp/cyber_colorizer.sh' C-m

tmux set-option -t $SESSION_NAME pane-border-style fg=colour=51,bold
tmux set-option -t $SESSION_NAME pane-active-border-style fg=colour=206,bold

echo -e "${NEON_CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${NEON_CYAN}${BOLD}║${NC} ${NEON_PINK}${BOLD}█▓▒░${NC} ${NEON_MAGENTA}${BOLD}🚀 NEXUS SECURITY v7.0 – LIVE FEED${NC} ${NEON_PINK}${BOLD}░▒▓█${NC} ${NEON_CYAN}${BOLD}║${NC}"
echo -e "${NEON_CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${NEON_RED}${BOLD}☠️ Hack the Planet! ☠️${NC}"
echo -e "${NEON_YELLOW}“The devil whispered: You are not strong enough... But I am the storm.” ${NEON_RED}🔥${NC}"
echo ""
echo -e "${NEON_GREEN}${BOLD}✅ Original Dashboard – only with the dark quote in one line!${NC}"
echo -e "  ${NEON_YELLOW}●${NC} No structural changes"
echo -e "  ${NEON_YELLOW}●${NC} Quote now in one line with 🔥"
echo ""

tmux attach -t $SESSION_NAME
