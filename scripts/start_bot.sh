#!/bin/bash
# Temporary daemon script for Cline Telegram Bot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_SCRIPT="$SCRIPT_DIR/cline_telegram_bot.py"
PID_FILE="$SCRIPT_DIR/bot.pid"
LOG_FILE="$SCRIPT_DIR/bot.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if bot is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Function to start bot
start_bot() {
    if is_running; then
        echo -e "${YELLOW}Bot is already running (PID: $(cat "$PID_FILE"))${NC}"
        return 1
    fi

    echo -e "${GREEN}Starting Cline Telegram Bot...${NC}"

    # Change to script directory
    cd "$SCRIPT_DIR"

    # Start bot in background
    nohup python3 "$BOT_SCRIPT" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    # Save PID
    echo $pid > "$PID_FILE"

    # Wait a moment and check if it's still running
    sleep 2
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}Bot started successfully (PID: $pid)${NC}"
        echo "Log file: $LOG_FILE"
        return 0
    else
        echo -e "${RED}Bot failed to start. Check log file: $LOG_FILE${NC}"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Function to stop bot
stop_bot() {
    if ! is_running; then
        echo -e "${YELLOW}Bot is not running${NC}"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    echo -e "${YELLOW}Stopping bot (PID: $pid)...${NC}"

    # Try graceful shutdown first
    kill -TERM $pid 2>/dev/null

    # Wait up to 10 seconds for graceful shutdown
    local count=0
    while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done

    # Force kill if still running
    if kill -0 $pid 2>/dev/null; then
        echo "Force killing bot..."
        kill -KILL $pid 2>/dev/null
        sleep 1
    fi

    if kill -0 $pid 2>/dev/null; then
        echo -e "${RED}Failed to stop bot${NC}"
        return 1
    else
        rm -f "$PID_FILE"
        echo -e "${GREEN}Bot stopped successfully${NC}"
        return 0
    fi
}

# Function to check status
status_bot() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}Bot is running (PID: $pid)${NC}"
        echo "Log file: $LOG_FILE"
        return 0
    else
        echo -e "${YELLOW}Bot is not running${NC}"
        return 1
    fi
}

# Function to show logs
logs_bot() {
    if [ -f "$LOG_FILE" ]; then
        echo "=== Bot Logs (last 50 lines) ==="
        tail -50 "$LOG_FILE"
    else
        echo -e "${YELLOW}No log file found${NC}"
    fi
}

# Function to restart bot
restart_bot() {
    echo "Restarting bot..."
    stop_bot
    sleep 2
    start_bot
}

# Function to auto-restart bot (monitor and restart if crashed)
auto_restart_bot() {
    local restart_count=0
    local max_restarts=10
    local restart_delay=30

    echo -e "${GREEN}Starting auto-restart mode...${NC}"
    echo "Bot will be automatically restarted if it crashes"
    echo "Press Ctrl+C to stop monitoring"

    # Start the bot initially
    if ! start_bot; then
        echo -e "${RED}Failed to start bot initially. Exiting auto-restart mode.${NC}"
        return 1
    fi

    # Monitor loop
    while true; do
        sleep 10  # Check every 10 seconds

        if ! is_running; then
            restart_count=$((restart_count + 1))

            if [ $restart_count -gt $max_restarts ]; then
                echo -e "${RED}Bot has crashed $max_restarts times. Stopping auto-restart mode.${NC}"
                return 1
            fi

            echo -e "${YELLOW}Bot crashed (attempt $restart_count/$max_restarts). Restarting in $restart_delay seconds...${NC}"

            # Wait before restarting
            local countdown=$restart_delay
            while [ $countdown -gt 0 ]; do
                echo -n "Restarting in $countdown seconds... "
                sleep 1
                countdown=$((countdown - 1))
                echo -ne "\r"
            done
            echo ""

            # Try to restart
            if ! start_bot; then
                echo -e "${RED}Failed to restart bot. Will try again in next cycle.${NC}"
            else
                echo -e "${GREEN}Bot restarted successfully${NC}"
            fi
        fi
    done
}

# Main script logic
case "${1:-help}" in
    start)
        start_bot
        ;;
    stop)
        stop_bot
        ;;
    restart)
        restart_bot
        ;;
    monitor|auto-restart)
        auto_restart_bot
        ;;
    status)
        status_bot
        ;;
    logs)
        logs_bot
        ;;
    tail)
        echo "Tailing log file (Ctrl+C to stop)..."
        tail -f "$LOG_FILE"
        ;;
    help|--help|-h)
        echo "Cline Telegram Bot Daemon Control Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|monitor|status|logs|tail|help}"
        echo ""
        echo "Commands:"
        echo "  start        - Start the bot as a background daemon"
        echo "  stop         - Stop the running bot"
        echo "  restart      - Restart the bot"
        echo "  monitor      - Auto-restart bot if it crashes (Ctrl+C to stop)"
        echo "  status       - Check if bot is running"
        echo "  logs         - Show last 50 lines of logs"
        echo "  tail         - Follow log file in real-time"
        echo "  help         - Show this help message"
        echo ""
        echo "Auto-restart mode:"
        echo "  - Monitors bot every 10 seconds"
        echo "  - Automatically restarts if bot crashes"
        echo "  - Limits to 10 restart attempts to prevent infinite loops"
        echo "  - 30-second delay between restart attempts"
        echo ""
        echo "Files:"
        echo "  PID file: $PID_FILE"
        echo "  Log file: $LOG_FILE"
        ;;
    *)
        echo -e "${RED}Invalid command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac