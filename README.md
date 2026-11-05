# OCL Decidim demo

A [Decidim](https://decidim.org) **0.32.2** demo for Open Cities Lab at **https://participate.opencitieslab.africa**.

It runs on one EC2 host in AWS `af-south-1` (Cape Town). Docker Compose runs the Rails app, Sidekiq, PostgreSQL, Redis and Caddy, which provides automatic HTTPS. DNS is in Cloudflare and email goes through Amazon SES, which is in sandbox mode.

> This is a demo for a handful of testers. It has no high availability and should not hold real citizen data. See `docs/plans/` for the design and what's deliberately out of scope.

## Layout

| Path | What |
|---|---|
| `Gemfile`, `app/`, `config/`, `db/`… | Decidim app generated with `decidim --queue sidekiq --locales en` (pinned to 0.32.2) |
| `Dockerfile` | Multi-stage build. There's no official 0.32.x image, so we build our own |
| `docker-compose.yml`, `Caddyfile` | The stack |
| `docker-compose.test.yml`, `spec/` | RSpec harness (`test` Dockerfile stage, own Postgres/Redis) |
| `config/initializers/cct.rb`, `config/locales/` | City of Cape Town customisations; en/af/xh locales |
| `deploy/provision.sh` | Creates the EC2 host: security group, key pair, instance, Elastic IP and daily snapshots. Everything is tagged `Project=decidim-demo` |
| `deploy/dns.sh` | Cloudflare A record (DNS-only), plus the SES domain identity with DKIM, SPF and DMARC records |
| `deploy/deploy.sh` | Copies `HEAD` to the host, builds, runs migrations, restarts and installs cron |
| `deploy/crontab` | Decidim's scheduled tasks |
| `deploy/env.production.example` | Template for the host's `.env.production` |
| `deploy/teardown.sh` | Destroys every tagged resource, the DNS records and the SES identity |

## Secrets

- `./.env` holds the **operator's** AWS and Cloudflare credentials. It's gitignored, used only on your machine, and **never copied to the server**. See `.env.example`.
- `/opt/decidim-demo/.env.production` lives **only on the host**, created by hand from `deploy/env.production.example`.
- `config/master.key` is gitignored and excluded from the image. Production uses `SECRET_KEY_BASE` instead.

## Run locally

```bash
# .env.production is gitignored. Locally set SITE_ADDRESS=localhost and random
# SECRET_KEY_BASE / DATABASE_PASSWORD values (openssl rand -hex 64 / -hex 24).
cp deploy/env.production.example .env.production
alias dc='docker compose --env-file .env.production'   # locally ./.env holds operator creds, so pass the file explicitly
dc up -d --build
dc exec app bin/rails db:create db:migrate   # never db:prepare (it seeds)
dc exec app bin/rails decidim_system:create_admin
# https://localhost/system  (Caddy's local CA, so accept the certificate warning)
# On the host, deploy.sh symlinks .env -> .env.production, so plain `docker compose` works there.
```

The interface is available in English, Afrikaans and isiXhosa (`DECIDIM_AVAILABLE_LOCALES=en,af,xh`, set in `docker-compose.yml`). Switch with the language chooser or the locale path prefix (`https://localhost/af/`, `/xh/`). Strings missing in af/xh fall back to English (`config/initializers/cct.rb`). The organisation must also have the three locales enabled (System → Organisations → edit).

### Local loop: change → reset → verify

```bash
dc down -v                                   # wipe the local DB, Redis and uploads (local only!)
dc up -d --build
dc exec app bin/rails db:create db:migrate   # never db:seed / db:prepare (default accounts)
dc exec app bin/rails cct:seed               # (from U6) real CCT data + labelled demo content
dc stop                                      # when done, to free RAM
```

### Specs

Specs run in a separate Compose project (`docker-compose.test.yml`, project `decidim-demo-test`) with its own Postgres (tmpfs) and Redis, so they never touch the local stack's data. The `test` Dockerfile stage adds the dev/test gems (`decidim-dev`, `rspec-rails`, FactoryBot) and pre-compiled test packs; the production image (the default, last stage) is unchanged.

```bash
alias dct='docker compose -f docker-compose.test.yml'
dct build                                    # again after Gemfile, package.json or app/packs changes
dct run --rm test                            # whole suite (creates + migrates the test DB first)
dct run --rm test bundle exec rspec spec/i18n/locales_spec.rb
dct down -v                                  # stop and drop the test DB
```

`app/`, `config/`, `db/`, `lib/` and `spec/` are bind-mounted, so edits there need no rebuild. Specs load Decidim's factories and helpers from `decidim-dev` (`spec/rails_helper.rb`, `spec/factories.rb`).

## First deploy

1. **Provision the host:** run `deploy/provision.sh`. It prints the SSH command and writes the IP to `deploy/.host-ip`. Wait about 3 minutes for cloud-init, which installs Docker and adds swap.
2. **Set up DNS and email:** run `deploy/dns.sh`. SES verification can take a few minutes.
3. **Create the SMTP user:** in IAM, create a user that may only call `ses:SendRawEmail` on the `participate.opencitieslab.africa` identity, then generate SES SMTP credentials for it. **Do not** use the operator key.
4. **Write the host's env file:** SSH in, then:
   ```bash
   cd /opt/decidim-demo
   # paste deploy/env.production.example into .env.production, then fill in:
   #   SECRET_KEY_BASE / DECIDIM_API_JWT_SECRET  -> openssl rand -hex 64
   #   DATABASE_PASSWORD                         -> openssl rand -hex 24
   #   SYSTEM_ALLOW_IPS                          -> OCL office/VPN IPs (Caddy-enforced; keep DECIDIM_SYSTEM_ACCESSLIST_IPS empty)
   #   SMTP_USERNAME / SMTP_PASSWORD             -> from step 3
   chmod 600 .env.production
   ```
5. **Deploy:** run `deploy/deploy.sh` from your machine. After the first deploy, generate the push keys on the host and add them to `.env.production`, then deploy again:
   ```bash
   docker compose exec app bin/rails decidim:pwa:generate_vapid_keys
   ```
6. **Create the system admin:** `docker compose exec app bin/rails decidim_system:create_admin`. Use a random password and save it in the OCL password manager.
7. **Create the organisation:** go to https://participate.opencitieslab.africa/system (allow-listed IPs only) and create it with:
   - host `participate.opencitieslab.africa`
   - locale `en`
   - time zone `Africa/Johannesburg`

   The organisation admin is invited by email.
8. **Theme it:** in Admin → Settings → Appearance, upload the OCL logo and favicon and set the colours to `#FCAF00` / `#D86139` / `#2F3542`. Then add a `terms-of-service` page.
9. **Add testers:** SES sandbox only delivers to verified addresses, so verify each one first:
   ```bash
   aws sesv2 create-email-identity --region af-south-1 --email-identity tester@example.org
   ```
   Then invite them, or let them self-register.

**Never** run `db:seed` in production. It creates well-known default accounts.

## Day-to-day

| Task | How |
|---|---|
| Update code or bump Decidim | Commit, then `deploy/deploy.sh`. For a 0.32.x bump, change `Gemfile`, run `bundle lock` in a `ruby:3.4.7` container, and redeploy (migrations run automatically) |
| Logs | `ssh … 'cd /opt/decidim-demo && docker compose logs -f app worker'`; cron output is in `log/cron.log` |
| Rails console | `docker compose exec app bin/rails console` |
| Create a user without email | In the console: `Decidim::User.create!(organization: Decidim::Organization.first, name:, nickname:, email:, password:, tos_agreement: true, confirmed_at: Time.current)` |
| Stop when idle | `aws ec2 stop-instances --region af-south-1 --instance-ids <id>`. The Elastic IP is kept but billed while stopped |
| Manual backup | `aws ec2 create-snapshot --region af-south-1 --volume-id <root-vol> --description decidim-demo-manual` |
| Restore | Create a volume from the snapshot, then swap it in as the instance's root volume |
| SSH from a new IP | Re-run `deploy/provision.sh`, which adds your current IP/32 to the security group |
| Destroy everything | `deploy/teardown.sh` (asks for confirmation) |

## Licence

Decidim is AGPL-3.0, and so is this app (`LICENSE-AGPLv3.txt`). Keep the repo's source available to anyone who uses the service.
