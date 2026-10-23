-- RLS policies call qualified helpers in the private `app` schema. Function
-- EXECUTE grants alone are insufficient when PostgREST parses those policies
-- for API roles: the role also needs schema USAGE. The schema remains excluded
-- from [api].schemas in config.toml, so this does not expose app.* over the Data
-- API; explicit function grants and RLS continue to decide what can run.
grant usage on schema app to anon, authenticated;
