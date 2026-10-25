#!/usr/bin/env python3
"""Use an available local Postgres port for Supabase checks on GitHub runners."""

from __future__ import annotations

import os
import re
import socket
import sys
from pathlib import Path


def port_is_available(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        try:
            listener.bind(("0.0.0.0", port))
        except OSError:
            return False
        return True


def find_available_port() -> int:
    # Let the OS select an unused ephemeral port rather than guessing a second
    # fixed port that could also be occupied by a runner service.
    for _ in range(10):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
            listener.bind(("0.0.0.0", 0))
            port = listener.getsockname()[1]
        if port_is_available(port):
            return port
    raise RuntimeError("Could not find an available local database port.")


def update_database_port(config_path: Path) -> int:
    config_text = config_path.read_text()
    section = re.search(r"(?ms)^\[db\][ \t]*\n(.*?)(?=^\[|\Z)", config_text)
    if section is None:
        raise RuntimeError("Could not find the [db] section in Supabase config.")

    port_setting = re.search(
        r"(?m)^[ \t]*port[ \t]*=[ \t]*(\d+)[ \t]*(?:#.*)?$",
        section.group(1),
    )
    if port_setting is None:
        raise RuntimeError("Could not find the [db].port setting.")
    database_port = int(port_setting.group(1))

    if not port_is_available(database_port):
        replacement_port = find_available_port()
        db_config = re.sub(
            r"(?m)^(\s*port\s*=\s*)\d+(\s*(?:#.*)?)$",
            rf"\g<1>{replacement_port}\g<2>",
            section.group(1),
            count=1,
        )
        if db_config == section.group(1):
            raise RuntimeError("Could not update the [db].port setting.")

        config_text = (
            config_text[: section.start(1)]
            + db_config
            + config_text[section.end(1) :]
        )
        config_path.write_text(config_text)
        print(
            f"Database port {database_port} is occupied; using "
            f"{replacement_port} for this CI run."
        )
        database_port = replacement_port
    else:
        print(f"Using available Supabase database port {database_port}.")

    github_env = os.environ.get("GITHUB_ENV")
    if github_env:
        database_url = (
            f"postgresql://postgres:postgres@127.0.0.1:{database_port}/postgres"
        )
        with open(github_env, "a", encoding="utf-8") as env_file:
            env_file.write(f"SUPABASE_DB_URL={database_url}\n")

    return database_port


if __name__ == "__main__":
    config = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("supabase/config.toml")
    update_database_port(config)
