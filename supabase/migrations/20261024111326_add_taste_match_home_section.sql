-- PostgreSQL requires a newly-added enum label to commit before another
-- migration can use it. Keep this enum-only migration separate from the code
-- that starts inserting TASTE_MATCH sections.
alter type public.home_section_kind add value if not exists 'TASTE_MATCH';
