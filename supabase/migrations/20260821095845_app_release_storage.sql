-- Public mobile update channel.
--
-- The manifest and split APKs are intentionally unauthenticated downloads so a
-- signed-in session is not required before the app can update itself. GitHub
-- Actions uploads them with the service-role key, which never ships in Flutter.
-- Split APKs stay below the 50 MB Supabase Free-plan file limit.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  true,
  52428800,
  array[
    'application/json',
    'application/vnd.android.package-archive',
    'application/octet-stream'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists app_releases_public_read on storage.objects;
create policy app_releases_public_read on storage.objects
for select to anon, authenticated
using (bucket_id = 'app-releases');
