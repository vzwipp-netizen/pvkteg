# PVKTEG — dark messenger starter

PVKTEG is a responsive web app/PWA plus an Android wrapper (Capacitor). It includes email/password auth, a profile/avatar flow, an AI chat through a server-side Supabase Edge Function, a star wallet, gift catalogue, gift inventory RPC, reactions, and a voice recording/upload flow.

## Important status
This is a runnable starter project, not a hosted production service. It does not create a live account or database automatically. You must configure a Supabase project and deploy the Edge Function. Real-money star purchases, push notifications, end-to-end encryption, group chats, and full NFT minting/marketplace are not implemented. The collectible gifts here are database collectibles, not blockchain NFTs. The initial 100 stars are demo credits.

## 1. Web setup
1. Install Node.js 20+ and create a free Supabase project at https://supabase.com.
2. In Supabase → SQL Editor, run `supabase/schema.sql`.
3. In Supabase → Authentication → Providers, enable Email. For quick testing, configure email confirmation as desired.
4. In Storage create buckets:
   - `avatars` (public; profile photos)
   - `voice` (private recommended; for production use signed URLs and add Storage policies).
5. Copy `.env.example` to `.env.local` and fill in the Supabase Project URL and anon/public key. Never use the service-role key in the browser.
6. Install and run:
   ```bash
   npm install
   npm run dev
   ```
7. Build:
   ```bash
   npm run build
   ```

## 2. Enable AI replies
From the project root, install the Supabase CLI and link your project. Set the secret on the server, not in `.env.local`:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set OPENAI_API_KEY=YOUR_OPENAI_API_KEY
supabase functions deploy chat-ai
```
The function authenticates the caller and forwards a limited chat history to OpenAI. API usage is billed to the API account; ChatGPT subscriptions do not include API credits. The model name can be changed in `supabase/functions/chat-ai/index.ts`.

## 3. Android app
Requires Android Studio, Android SDK, and Java 17:
```bash
npm install
npm run build
npx cap add android
npx cap sync android
npx cap open android
```
In Android Studio, run on a device/emulator or build a signed APK/AAB. For each web update, run `npm run android:sync`. Use HTTPS hosting for the production web app; Android microphone permission may need to be declared in the native manifest for voice recording.

## 4. Current demo behavior / production work
- Sign-up/sign-in uses Supabase Auth (email + password).
- Profile creation is automatic via a database trigger.
- Gift purchase is an atomic server-side RPC and deducts stars from the sender. The current UI buys gifts for the signed-in user; recipient selection and gift delivery UX should be completed before public launch.
- Chat list currently shows the AI chat and a basic new-chat UUID entry point. The schema supports direct messages, but realtime subscriptions, conversation list queries, and full recipient UI are next implementation steps.
- Reactions currently update the local UI only; persist them in a `message_reactions` table for production.
- Voice recording uploads to Storage. Configure private bucket policies and signed URLs before public launch.
- Do not use demo stars as a monetary balance. Add a payment provider and server-verified webhook before selling stars. NFT claims require an explicit chain, wallet custody model, legal review, and minting integration.

## Security checklist before public launch
- Configure Supabase RLS and storage policies for every bucket.
- Restrict CORS to your deployed domains.
- Add rate limits and abuse controls to the AI function.
- Add message pagination, realtime delivery, reporting/blocking, account deletion/export, backups, and moderation.
- Use signed URLs for private voice media.
- Do not claim end-to-end encryption unless it is actually implemented and independently reviewed.


## Developer account / admin panel
Create the Auth user in Supabase Auth with email `vzwipp@gmail.com` and set the password privately in the Supabase dashboard or sign-up flow. Do not hardcode the password in source code, SQL, or frontend JavaScript. The SQL migration marks this email as admin in `profiles.is_admin`; it also backfills an already-created matching account. Run the updated `supabase/schema.sql` in SQL Editor after deploying the updated app. The admin panel is only rendered for an admin profile, and the database RPCs independently enforce `is_admin` before granting stars or issuing arbitrary collectible gifts.

The current star top-up screen is a non-payment placeholder. Do not accept real money until a payment provider and server-verified webhook are implemented.

## Сборка APK без компьютера (через GitHub)

В архив добавлен GitHub Actions workflow `.github/workflows/android.yml`. Он автоматически собирает **debug APK** в облаке.

1. На телефоне скачайте архив проекта и распакуйте его.
2. На GitHub создайте новый пустой репозиторий (например, `pvkteg`).
3. Загрузите **содержимое папки `pvkteg`** в корень репозитория. В корне должны быть `package.json`, `src/`, `capacitor.config.ts` и `.github/`.
4. Откройте вкладку **Actions** репозитория. Если GitHub попросит разрешить запуск workflows, нажмите разрешение.
5. Выберите **Build PVKTEG APK** → **Run workflow** → **Run workflow**.
6. Дождитесь зелёной галочки. Откройте завершённый запуск, прокрутите до **Artifacts** и скачайте `PVKTEG-debug-APK`.
7. Распакуйте скачанный ZIP и установите `app-debug.apk` на Android. При запросе разрешите установку из этого источника.

Каждый новый push в ветку `main` или `master` также запускает сборку. Это отладочная APK-сборка, не опубликованная в Google Play и не подписанная релизным ключом.

**Важно:** сборка APK не разворачивает серверную часть. Для входа, синхронизации и AI-функций отдельно настройте Supabase и секреты, как описано выше в README. Реальные платежи за звёзды в проекте пока не реализованы.
