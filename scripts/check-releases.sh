#!/bin/bash
#
# Check whether the tracked upstream branch tip has already been built.
#
# Mirrors the dedup logic of the CI check-branch job in
# .github/workflows/build-cuda.yml: resolves the iq1-narrow branch tip commit
# SHA and checks whether a release tagged unsloth-iq1-narrow-<shortsha> exists.

set -e

# ---- Upstream fork (defaults match CI workflow env) ----
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/unslothai/llama.cpp}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-iq1-narrow}"
THIS_REPO="${THIS_REPO:-ai-dock/llama.cpp-cuda}"

# Strip scheme/host to get owner/repo for the API
UPSTREAM_API="${UPSTREAM_REPO#https://github.com/}"

# jq is required so this script parses the GitHub API the same robust way the
# CI check-branch job does (resilient to JSON field reordering), instead of the
# brittle grep | head -1 | sed approach.
command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required. Install it (e.g. 'sudo apt-get install -y jq')." >&2
    exit 1
}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}llama.cpp-cuda Branch Tracker${NC}"
echo "================================"
echo "Upstream:  ${UPSTREAM_REPO} (branch: ${UPSTREAM_BRANCH})"
echo "This repo: ${THIS_REPO}"
echo ""

# ---- Upstream: tip commit of the tracked branch ----
echo "Checking upstream branch tip..."
BRANCH_JSON=$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_API}/branches/${UPSTREAM_BRANCH}")
TIP_SHA=$(printf '%s' "${BRANCH_JSON}" | jq -r '.commit.sha // empty')
TIP_DATE=$(printf '%s' "${BRANCH_JSON}" | jq -r '.commit.commit.committer.date // empty')
SHORT_SHA="${TIP_SHA:0:7}"

if [ -z "${TIP_SHA}" ]; then
    echo -e "${RED}Could not resolve tip of ${UPSTREAM_BRANCH}${NC}"
    exit 1
fi

echo -e "Upstream tip:  ${GREEN}${SHORT_SHA}${NC} (${TIP_SHA})"
echo "Committed:     ${TIP_DATE}"
echo ""

# ---- This repo: does a release for this commit already exist? ----
# Releases are tagged unsloth-iq1-narrow-<shortsha>.
echo "Checking ${THIS_REPO} for an existing build of this commit..."
CANDIDATE_TAG="unsloth-${UPSTREAM_BRANCH}-${SHORT_SHA}"
OUR_TAG=$(curl -fsSL "https://api.github.com/repos/${THIS_REPO}/releases" \
    | jq -r --arg tag "${CANDIDATE_TAG}" '.[] | select(.tag_name == $tag) | .tag_name' \
    | head -1 || true)

if [ -n "${OUR_TAG}" ]; then
    echo -e "${GREEN}✓ Up to date!${NC}"
    echo "Commit ${SHORT_SHA} has already been built (release tag ${OUR_TAG})."
else
    echo -e "${YELLOW}⚠ New build needed!${NC}"
    echo "Upstream ${UPSTREAM_BRANCH} is at ${SHORT_SHA} but no release tagged ${CANDIDATE_TAG} exists."
    echo ""
    echo "A new build should be triggered automatically within 24 hours."
    echo "Or manually trigger: https://github.com/${THIS_REPO}/actions"
fi

echo ""
echo "Links:"
echo "  Upstream branch: https://github.com/${UPSTREAM_API}/tree/${UPSTREAM_BRANCH}"
echo "  Upstream commit: https://github.com/${UPSTREAM_API}/commit/${TIP_SHA}"
echo "  Our releases:    https://github.com/${THIS_REPO}/releases"
