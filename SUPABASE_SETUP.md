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
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
```

If no Supabase config is provided, the app starts in local empty-data mode.

## 5. Auth setting required for easiest signup

In Supabase dashboard:

- open `Authentication`
- open `Providers`
- keep `Email` enabled
- for the smoothest in-app signup flow, disable email confirmation while testing

If email confirmation stays enabled, Supabase may create the account but not start a logged-in session immediately.

## 6. What is now stored in Supabase

The app now saves and loads these live records from Supabase:

- teacher accounts and permissions
- school settings and result deadlines
- student registrations
- subject result sheets and exam marks
- signed-up user profiles
- first-login auto-created profile for an existing Supabase auth user when no app profile exists yet

Creating the Supabase project alone does not add the tables automatically. You must run the migration SQL to create all fields used by this Flutter app.
