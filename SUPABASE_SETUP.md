# Supabase Setup

This project now expects Supabase instead of Firebase.

## 1. Create the project

Create your project in the Supabase dashboard first. After that, the app still needs the database schema to be created inside that project.

## 2. Add the schema and fields

Open `SQL Editor` in Supabase and run the migration from:

`supabase/migrations/20260418142349_init_schema.sql`

Important:

- paste the SQL content only
- do not paste the filename `20260418142349_init_schema.sql`
- the editor must start with SQL like `create extension...`, not the file name

That migration creates these tables and their fields:

- `districts`
- `schools`
- `classes`
- `users`
- `teachers`
- `students`
- `exams`
- `results`
- `settings`

It also creates:

- foreign keys between district, school, class, student, exam, and result records
- `updated_at` triggers
- indexes
- row level security policies

## 3. Optional starter data

`supabase/seed.sql` is intentionally empty now so the system starts with real data only.

If you previously inserted demo rows, run:

`supabase/cleanup_demo_data.sql`

## 4. Connect the Flutter app

You can either keep the values directly in `lib/main.dart` or pass them at runtime with `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://mnvspcycpbanqdrxrkgy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_VpBQlmnFXh66ExZPtWJOhA_bZbHGh-E
```

If no Supabase config is provided, the app starts in local empty-data mode.

## 5. Auth setting required for account creation

In Supabase dashboard:

- open `Authentication`
- open `Providers`
- keep `Email` enabled
- disable public email signups
- create teacher accounts only from the logged-in headmaster workflow

The FastAPI backend must have `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
The Flutter app sends the current headmaster Supabase access token to
`POST /api/v1/admin/teachers`; the backend validates that profile as
`head_of_school`, creates the Supabase Auth user with the service-role key, and
writes the linked `public.users` and `public.teachers` rows.

For Vercel builds, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the frontend
Supabase project settings. `SUPABASE_KEY` is also accepted by the build script
as an alias for `SUPABASE_ANON_KEY`. `BACKEND_API_URL` should point to
`https://student-system-h7pi.onrender.com/api/v1`.

If you override backend CORS with `ALLOWED_ORIGINS`, include the frontend origin
too, for example `https://student-flax-psi.vercel.app`. Vercel deployment URLs
for this project are also allowed by the default `ALLOWED_ORIGIN_REGEX`.

## 6. What is now stored in Supabase

The app now saves and loads these live records from Supabase:

- teacher accounts and permissions
- school settings and result deadlines
- student registrations
- subject result sheets and exam marks
- admin-created user profiles

Creating the Supabase project alone does not add the tables automatically. You must run the migration SQL to create all fields used by this Flutter app.
