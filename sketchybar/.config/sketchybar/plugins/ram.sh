#!/usr/bin/env bash

# Read page counts (free, active, inactive, speculative)
P_FREE=$(vm_stat | awk '/Pages free:/         {print $3}' | tr -d '.')   #  [oai_citation:1‡apple.stackexchange.com](https://apple.stackexchange.com/questions/423717/is-there-a-command-line-tool-that-accurately-describes-the-amount-of-used-memory?utm_source=chatgpt.com)
P_ACTIVE=$(vm_stat | awk '/Pages active:/       {print $3}' | tr -d '.')   #  [oai_citation:2‡apple.stackexchange.com](https://apple.stackexchange.com/questions/423717/is-there-a-command-line-tool-that-accurately-describes-the-amount-of-used-memory?utm_source=chatgpt.com)
P_INACTIVE=$(vm_stat | awk '/Pages inactive:/   {print $3}' | tr -d '.')   #  [oai_citation:3‡apple.stackexchange.com](https://apple.stackexchange.com/questions/423717/is-there-a-command-line-tool-that-accurately-describes-the-amount-of-used-memory?utm_source=chatgpt.com)
P_SPEC=$(vm_stat | awk '/Pages speculative:/   {print $3}' | tr -d '.')   #  [oai_citation:4‡apple.stackexchange.com](https://apple.stackexchange.com/questions/423717/is-there-a-command-line-tool-that-accurately-describes-the-amount-of-used-memory?utm_source=chatgpt.com)

# Get page size in bytes
PAGE_SIZE=$(sysctl -n vm.pagesize)                                           #  [oai_citation:5‡superuser.com](https://superuser.com/questions/197059/mac-os-x-sysctl-get-total-and-free-memory-size?utm_source=chatgpt.com)

# Calculate total & used bytes
TOTAL_BYTES=$(( (P_FREE + P_ACTIVE + P_INACTIVE + P_SPEC) * PAGE_SIZE ))      #  [oai_citation:6‡stackoverflow.com](https://stackoverflow.com/questions/14150626/understanding-vm-stat-in-mac-os-how-to-convert-those-numbers-to-something-simil?utm_source=chatgpt.com)
USED_BYTES=$(( (P_ACTIVE + P_INACTIVE + P_SPEC) * PAGE_SIZE ))                #  [oai_citation:7‡stackoverflow.com](https://stackoverflow.com/questions/14150626/understanding-vm-stat-in-mac-os-how-to-convert-those-numbers-to-something-simil?utm_source=chatgpt.com)

# Convert to MB
TOTAL_MB=$(( TOTAL_BYTES / 1024 / 1024 ))                                     #  [oai_citation:8‡apple.stackexchange.com](https://apple.stackexchange.com/questions/4286/is-there-a-mac-os-x-terminal-version-of-the-free-command-in-linux-systems?utm_source=chatgpt.com)
USED_MB=$(( USED_BYTES / 1024 / 1024 ))                                       #  [oai_citation:9‡apple.stackexchange.com](https://apple.stackexchange.com/questions/4286/is-there-a-mac-os-x-terminal-version-of-the-free-command-in-linux-systems?utm_source=chatgpt.com)

# Compute percentage
PCT=$(( USED_MB * 100 / TOTAL_MB ))                                           #  [oai_citation:10‡superuser.com](https://superuser.com/questions/1107473/vm-stat-displays-less-memory-than-in-real?utm_source=chatgpt.com)

# Output for SketchyBar
echo "${PCT}%"
