#!/usr/bin/env bash
set -eo pipefail

echo "================================================================="
echo "  NEW RELIC ORPHAN DASHBOARD CLEANUP & DEDUPLICATION"
echo "================================================================="

if [ -z "$NEWRELIC_API_KEY" ]; then
  echo "[WARN] NEWRELIC_API_KEY is not set. Skipping New Relic dashboard cleanup."
  exit 0
fi

MANAGED_NAMES=(
  "API Garage - Painel Executivo de Negocios & SLAs"
  "API Garage - Infraestrutura, Latência & Integrações"
  "Keycloak - Identity & Authentication Server"
  "PostgreSQL RDS - Database Performance & Pool Health"
)

# 1. Extract active dashboard GUIDs from Terraform State (if available)
ACTIVE_GUIDS=()
if command -v terraform >/dev/null 2>&1; then
  echo "[INFO] Extracting active dashboard GUIDs from Terraform state..."
  TF_STATE_JSON=$(terraform show -json 2>/dev/null || echo "{}")
  while IFS= read -r guid; do
    if [ -n "$guid" ] && [ "$guid" != "null" ]; then
      ACTIVE_GUIDS+=("$guid")
    fi
  done < <(echo "$TF_STATE_JSON" | jq -r '.. | objects | select(.type? == "newrelic_one_dashboard_json") | .values.guid // empty' 2>/dev/null || true)
fi

echo "[INFO] Active dashboard GUIDs in Terraform state: ${#ACTIVE_GUIDS[@]}"
for g in "${ACTIVE_GUIDS[@]}"; do
  echo "  - Active GUID: $g"
done

# 2. Query New Relic NerdGraph API for all dashboards
echo "[INFO] Querying New Relic NerdGraph for managed dashboards..."
GRAPHQL_QUERY='{ actor { entitySearch(queryBuilder: {type: DASHBOARD}) { results { entities { ... on DashboardEntityOutline { guid name createdAt } } } } } }'
RESPONSE=$(curl -s -X POST "https://api.newrelic.com/graphql" \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NEWRELIC_API_KEY}" \
  -d "$(jq -n --arg q "$GRAPHQL_QUERY" '{query: $q}')")

ENTITIES_COUNT=$(echo "$RESPONSE" | jq -r '.data.actor.entitySearch.results.entities | length' 2>/dev/null || echo 0)
echo "[INFO] Total dashboard entities found in New Relic account: $ENTITIES_COUNT"

if [ "$ENTITIES_COUNT" -eq 0 ]; then
  echo "[INFO] No dashboards found in New Relic. Nothing to clean up."
  exit 0
fi

# 3. Identify and delete orphaned dashboards
DELETED_COUNT=0
for name in "${MANAGED_NAMES[@]}"; do
  echo "[INFO] Checking managed dashboard: '$name'..."
  MATCHING=$(echo "$RESPONSE" | jq -c --arg name "$name" \
    '.data.actor.entitySearch.results.entities[] | select(.name == $name and (.name | contains(" / ") | not))')

  while IFS= read -r item; do
    [ -z "$item" ] && continue
    guid=$(echo "$item" | jq -r '.guid')
    createdAt=$(echo "$item" | jq -r '.createdAt')

    IS_ACTIVE=false
    for active_guid in "${ACTIVE_GUIDS[@]}"; do
      if [ "$active_guid" == "$guid" ]; then
        IS_ACTIVE=true
        break
      fi
    done

    if [ "$IS_ACTIVE" == "true" ]; then
      echo "  [KEEP] Dashboard '$name' (GUID: $guid, Created: $createdAt) is tracked in active Terraform state."
    else
      echo "  [DELETE] Deleting orphan/duplicate dashboard '$name' (GUID: $guid, Created: $createdAt)..."
      DEL_MUTATION="mutation { dashboardDelete(guid: \"$guid\") { status errors { description } } }"
      DEL_RESP=$(curl -s -X POST "https://api.newrelic.com/graphql" \
        -H "Content-Type: application/json" \
        -H "API-Key: ${NEWRELIC_API_KEY}" \
        -d "$(jq -n --arg q "$DEL_MUTATION" '{query: $q}')")

      STATUS=$(echo "$DEL_RESP" | jq -r '.data.dashboardDelete.status' 2>/dev/null || echo "FAILED")
      if [ "$STATUS" == "SUCCESS" ]; then
        echo "  [SUCCESS] Deleted orphan dashboard GUID: $guid"
        DELETED_COUNT=$((DELETED_COUNT + 1))
      else
        echo "  [WARN] Failed to delete dashboard GUID: $guid - $DEL_RESP"
      fi
    fi
  done <<< "$MATCHING"
done

echo "================================================================="
echo "  CLEANUP COMPLETE: $DELETED_COUNT orphan dashboard(s) deleted."
echo "================================================================="