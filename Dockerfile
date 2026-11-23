# Qinglong on Railway: the official image, pinned by version and digest.
# Bump both together; CHANGELOG.md says what changed for deployers.
FROM whyour/qinglong:2.24.0@sha256:2431b8b92d5822423d7d598110294691ae2a32d7fbde5c5d5a963db8b4f47cc3

# Railway sits in front as one reverse-proxy hop, so trust exactly one
# X-Forwarded-For entry (real client IPs in login logs and login throttling).
# TZ: cron schedules run in this zone; upstream's image defaults to Asia/Shanghai.
ENV QL_TRUST_PROXY=1 \
    TZ=UTC \
    NODE_OPTIONS="--require /railway/cpu-cap.cjs"

COPY railway/ /railway/
RUN chmod 755 /railway/railway-start.sh

EXPOSE 5700
ENTRYPOINT ["/railway/railway-start.sh"]
