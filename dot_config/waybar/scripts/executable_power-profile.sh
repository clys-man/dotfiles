#!/usr/bin/env bash

set -euo pipefail

profiles=(performance balanced power-saver)
available_profiles=()

while IFS= read -r profile; do
  available_profiles+=("$profile")
done < <(powerprofilesctl list | grep -Eo 'performance|balanced|power-saver' | awk '!seen[$0]++')

if [[ ${#available_profiles[@]} -eq 0 ]]; then
  notify-send "Power profile" "No power profiles available"
  exit 1
fi

current_profile="$(powerprofilesctl get)"
next_profile=""

for i in "${!profiles[@]}"; do
  if [[ "${profiles[$i]}" == "$current_profile" ]]; then
    for offset in 1 2 3; do
      candidate="${profiles[$(((i + offset) % ${#profiles[@]}))]}"
      for available in "${available_profiles[@]}"; do
        if [[ "$available" == "$candidate" ]]; then
          next_profile="$candidate"
          break 2
        fi
      done
    done
  fi
done

if [[ -z "$next_profile" ]]; then
  next_profile="${available_profiles[0]}"
fi

powerprofilesctl set "$next_profile"

notify-send "Power profile" "Active: $next_profile"
