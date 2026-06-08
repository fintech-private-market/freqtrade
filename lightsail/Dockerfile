# ==============================================================================
# Freqtrade - Lightsail Production Image
# Based on the official stable image. user_data is NOT copied here;
# it is mounted as a persistent volume via docker-compose.lightsail.yml
# ==============================================================================
FROM freqtradeorg/freqtrade:stable

# Optional: install psycopg driver for PostgreSQL support
# Remove this line if you plan to keep SQLite as the trade database
RUN pip install --user --no-cache-dir "psycopg[binary]"
