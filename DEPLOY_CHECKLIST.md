# Deploy Checklist (Laravel 13)

This project is ready to deploy to a PHP host. The fastest route is Laravel Cloud.

## 1) Put this code in your own GitHub repository

Your current git remote points to the Laravel starter repository, not your app repository.

Run this from the project root:

```bash
git remote remove origin
git remote add origin https://github.com/<your-user>/<your-repo>.git
git branch -M main
git push -u origin main
```

## 2) Deploy on Laravel Cloud

1. Go to Laravel Cloud and create a new project.
2. Connect your GitHub repository.
3. Select this repository and deploy the `main` branch.
4. Add a managed PostgreSQL database service.
5. Add a queue worker as a Background process on your App cluster (or a dedicated Worker cluster).

## 3) Set required environment variables

Use these values in Laravel Cloud:

```env
APP_NAME=Franssiss Invoicing
APP_ENV=production
APP_DEBUG=false
APP_URL=https://<your-domain>

DB_CONNECTION=pgsql
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=database
FILESYSTEM_DISK=public
LOG_LEVEL=warning

# OCR in cloud (tesseract binary usually unavailable)
OCR_DRIVER=ocr_space
OCR_SPACE_API_KEY=<your-ocr-space-api-key>
OCR_SPACE_LANGUAGE=eng
OCR_SPACE_MAX_FILE_SIZE=1000000
```

Notes:
- Keep APP_KEY secret.
- Do not use sqlite in production for cloud deployments.
- If you will send emails, configure MAIL_* variables for your SMTP provider.
- For OCR in Laravel Cloud, prefer OCR.space via `OCR_DRIVER=ocr_space`.
- OCR.space free tier allows about 1 MB per file. Use smaller receipt images or a PRO key for larger files.

## 4) Run first-time production commands

After first deploy, run:

```bash
php artisan key:generate --force
php artisan migrate --force
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

## 5) Ensure queue worker is running

In Laravel Cloud's current UI, queue workers are configured as Background processes.

1. Click your App cluster card in the infrastructure canvas.
2. In the cluster settings panel, open Background processes.
3. Click New background process.
4. Choose Queue worker and set the command.
5. Save and Deploy.

Set the worker start command to:

```bash
php artisan queue:work --tries=3 --timeout=120
```

## 6) Domain and HTTPS

1. Attach your custom domain in Laravel Cloud.
2. Update DNS records as instructed by Laravel Cloud.
3. Confirm SSL is active.
4. Update APP_URL to the final domain.

## 7) Post-deploy smoke test

1. Open home page and login/register screens.
2. Create a test invoice and verify totals.
3. Generate a PDF invoice.
4. Verify queued job processing.
5. Check logs for errors.

## Optional: if receipts or generated files must persist


### Persistent receipt uploads (S3 setup required)

If you want uploaded receipts and files to persist across deployments and server restarts, you must use S3 (or compatible) storage:

1. Create an S3 bucket (or use a compatible provider like DigitalOcean Spaces, Wasabi, etc).
2. In your `.env` file, set:

```env
FILESYSTEM_DISK=s3
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=your-region
AWS_BUCKET=your-bucket-name
AWS_URL=https://your-bucket-url (optional, for custom domains)
```

3. In `config/filesystems.php`, ensure the `s3` disk is configured (Laravel default is fine for AWS):

```php
		's3' => [
			'driver' => 's3',
			'key' => env('AWS_ACCESS_KEY_ID'),
			'secret' => env('AWS_SECRET_ACCESS_KEY'),
			'region' => env('AWS_DEFAULT_REGION'),
			'bucket' => env('AWS_BUCKET'),
			'url' => env('AWS_URL'),
			'endpoint' => env('AWS_ENDPOINT'),
		],
```

4. Deploy and test uploading/previewing receipts. All new uploads will be stored on S3.

5. (Optional) Migrate existing files from local storage to S3 if needed.
