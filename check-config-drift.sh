#!/bin/bash

# Compares local production files against the master branch on GitHub.
# Run this manually on the server to detect drift.
#
# Usage: ./check-config-drift [directory]
#
# Examples:
#   ./check-config-drift            # files at repo root → /home/psikoi/wise-old-man/
#   ./check-config-drift main       # files under main/  → /home/psikoi/wise-old-man/main/
#   ./check-config-drift secondary  # files under secondary/ → /home/psikoi/wise-old-man/secondary/

SERVER_DIR="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "$SERVER_DIR" ]; then
  BASE_DIR="${SCRIPT_DIR}/${SERVER_DIR}"
else
  BASE_DIR="${SCRIPT_DIR}"
fi

GITHUB_REPO="wise-old-man/wiseoldman-deploy-configs"
GITHUB_BRANCH="master"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/git/trees/${GITHUB_BRANCH}?recursive=1"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

diffs_found=0
errors_found=0

echo ""
if [ -n "$SERVER_DIR" ]; then
  echo -e "${BOLD}Fetching file list from ${GITHUB_REPO}@${GITHUB_BRANCH} (${SERVER_DIR}/)...${RESET}"
else
  echo -e "${BOLD}Fetching file list from ${GITHUB_REPO}@${GITHUB_BRANCH}...${RESET}"
fi
echo ""

# Extract blob paths from the GitHub tree API response
all_files=$(curl -sf "$GITHUB_API" | awk '/"path":/{gsub(/.*"path": "/,""); gsub(/".*/,""); path=$0} /"type": "blob"/{print path}' | grep -v '^\.github/')

if [ -z "$all_files" ]; then
  echo -e "${RED}ERROR${RESET} Could not fetch file list from GitHub API. Check network or repo URL."
  exit 1
fi

if [ -n "$SERVER_DIR" ]; then
  github_files=$(echo "$all_files" | grep "^${SERVER_DIR}/")
  if [ -z "$github_files" ]; then
    echo -e "${RED}ERROR${RESET} No files found under '${SERVER_DIR}/' in the GitHub tree. Check the directory name."
    exit 1
  fi
else
  github_files="$all_files"
fi

echo -e "${BOLD}Comparing files...${RESET}"
echo ""

IGNORE_FILES=("README.md" "LICENSE" ".gitignore" ".env.example")

while IFS= read -r file; do
  if [ -n "$SERVER_DIR" ]; then
    relative="${file#${SERVER_DIR}/}"
  else
    relative="$file"
  fi

  skip=0
  for ignore in "${IGNORE_FILES[@]}"; do
    [ "$relative" = "$ignore" ] && skip=1 && break
  done
  [ $skip -eq 1 ] && continue

  local_path="${BASE_DIR}/${relative}"
  remote_url="${GITHUB_RAW}/${file}"

  if [ ! -f "$local_path" ]; then
    echo -e "${RED}MISSING${RESET}  $relative"
    echo "         (exists on GitHub but not found locally)"
    echo ""
    diffs_found=1
    continue
  fi

  remote_content=$(curl -sf "$remote_url")
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}ERROR${RESET}    $relative"
    echo "         (could not fetch from GitHub)"
    echo ""
    errors_found=1
    continue
  fi

  diff_output=$(diff <(printf '%s' "$remote_content") <(printf '%s' "$(cat "$local_path")") | awk '
    function flush() {
      max = (gc > lc) ? gc : lc
      for (i = 1; i <= max; i++) {
        if (action == "a") {
          printf "         line %d:\n", ll + i - 1
          printf "           local:  %s\n", (i <= lc) ? llines[i] : "(none)"
        } else if (action == "d") {
          printf "         line %d:\n", gl + i - 1
          printf "           github: %s\n", (i <= gc) ? glines[i] : "(none)"
        } else {
          printf "         line %d:\n", gl + i - 1
          if (i <= gc) printf "           github: %s\n", glines[i]
          if (i <= lc) printf "           local:  %s\n", llines[i]
        }
      }
      gc = 0; lc = 0
      delete glines; delete llines
    }
    /^[0-9]/ {
      flush()
      cmd = $0
      for (j = 1; j <= length(cmd); j++) {
        ch = substr(cmd, j, 1)
        if (ch == "a" || ch == "c" || ch == "d") {
          action = ch; left = substr(cmd, 1, j-1); right = substr(cmd, j+1); break
        }
      }
      split(left, la, ","); split(right, ra, ",")
      gl = la[1]+0; ll = ra[1]+0
    }
    /^< / { gc++; glines[gc] = substr($0, 3) }
    /^> / { lc++; llines[lc] = substr($0, 3) }
    /^---$/ { next }
    END { flush() }
  ')

  if [ -n "$diff_output" ]; then
    echo -e "${RED}DIFF${RESET}     $relative"
    echo "$diff_output"
    echo ""
    diffs_found=1
  else
    echo -e "${GREEN}OK${RESET}       $relative"
  fi
done <<< "$github_files"

# Build a list of relative paths from github_files (strip SERVER_DIR prefix if present)
if [ -n "$SERVER_DIR" ]; then
  github_relatives=$(echo "$github_files" | sed "s|^${SERVER_DIR}/||")
else
  github_relatives="$github_files"
fi

# Check for local files that don't exist on GitHub
while IFS= read -r local_file; do
  relative="${local_file#${BASE_DIR}/}"

  # Skip .env (gitignored by design), .git/, and files not needed in production
  case "$relative" in
    .env|.git/*) continue ;;
  esac

  skip=0
  for ignore in "${IGNORE_FILES[@]}"; do
    [ "$relative" = "$ignore" ] && skip=1 && break
  done
  [ $skip -eq 1 ] && continue

  if ! echo "$github_relatives" | grep -qx "$relative"; then
    echo -e "${YELLOW}LOCAL ONLY${RESET}  $relative"
    diffs_found=1
  fi
done < <(find "$BASE_DIR" -type f -not -path '*/.git/*' | sort)

# Check that .env keys match .env.example keys
echo ""
echo -e "${BOLD}Checking .env keys against .env.example...${RESET}"
echo ""

env_file="${BASE_DIR}/.env"
example_remote="${GITHUB_RAW}/${SERVER_DIR:+${SERVER_DIR}/}.env.example"

if [ ! -f "$env_file" ]; then
  echo -e "${RED}MISSING${RESET}  .env not found at ${env_file}"
  diffs_found=1
else
  example_content=$(curl -sf "$example_remote")
  if [ -z "$example_content" ]; then
    echo -e "${YELLOW}SKIP${RESET}     Could not fetch .env.example from GitHub"
  else
  example_keys=$(printf '%s' "$example_content" | grep -v '^\s*#' | grep '=' | cut -d'=' -f1 | sort)
  env_keys=$(grep -v '^\s*#' "$env_file" | grep '=' | cut -d'=' -f1 | sort)

  keys_only_in_example=$(comm -23 <(echo "$example_keys") <(echo "$env_keys"))
  keys_only_in_env=$(comm -13 <(echo "$example_keys") <(echo "$env_keys"))

  if [ -z "$keys_only_in_example" ] && [ -z "$keys_only_in_env" ]; then
    echo -e "${GREEN}OK${RESET}       .env keys match .env.example"
  else
    if [ -n "$keys_only_in_example" ]; then
      echo -e "${RED}MISSING${RESET}  Keys in .env.example but not in .env:"
      echo "$keys_only_in_example" | sed 's/^/         /'
      diffs_found=1
    fi
    if [ -n "$keys_only_in_env" ]; then
      echo -e "${YELLOW}EXTRA${RESET}    Keys in .env but not in .env.example:"
      echo "$keys_only_in_env" | sed 's/^/         /'
      diffs_found=1
    fi
    echo ""
  fi
  fi
fi

echo ""
if [ $diffs_found -eq 0 ] && [ $errors_found -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All files are in sync.${RESET}"
else
  echo -e "${RED}${BOLD}Drift detected — review the diffs above.${RESET}"
fi
echo ""
