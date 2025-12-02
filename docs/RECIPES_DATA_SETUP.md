# recipes-en.json Setup

The `db/data/recipes-en.json` file (5.7 MB) contains the recipe data to import. It is not versioned in Git because it is too large.

## Downloading the file

To download the file from S3, use the rake task:

```bash
rails recipes:download
```

This command:
1. Downloads the compressed file from S3
2. Automatically decompresses it
3. Places it in `db/data/recipes-en.json`

## Verification

To verify that the file is present and accessible:

```bash
rails recipes:check_file
```

## Importing recipes

Once the file is downloaded, you can import the recipes:

```bash
rails recipes:import
```

## In development

The file is ignored by Git (see `.gitignore`). Each developer must download it locally with `rails recipes:download`.

## In production (Docker/Kamal)

### Option 1: Download during Docker build

Add to your `Dockerfile` before copying the code:

```dockerfile
# Download recipes data file
RUN mkdir -p /rails/db/data && \
    curl -L https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz | \
    gunzip > /rails/db/data/recipes-en.json
```

### Option 2: Download via rake task at startup

In your startup script or in `bin/docker-entrypoint`, add:

```bash
if [ ! -f db/data/recipes-en.json ]; then
  echo "Downloading recipes-en.json..."
  rails recipes:download
fi
```

### Option 3: Persistent volume

If you're using Kamal with volumes, you can download the file once and mount it as a persistent volume in `config/deploy.yml`:

```yaml
volumes:
  - "recipe_app_storage:/rails/storage"
  - "./db/data:/rails/db/data:ro"  # Mount local data directory
```

## Source file URL

The file is hosted at:
```
https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz
```
