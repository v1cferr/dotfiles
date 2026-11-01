"""Make Hydra's download sources match a declared catalog query: docs/notes/apps/hydralauncher.md

Hydra keeps them in its LevelDB, under the `downloadSources` sublevel, keyed by the id its API
hands out for each URL. This does what the app's own add/remove events do (the API call, then the
put or del), so the app sees a source it could have added itself.
"""

import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import plyvel

# The API the app itself talks to, read from the build (MAIN_VITE_API_URL); unauthenticated here.
API = "https://hydra-api-us-east-1.losbroxas.org"
PREFIX = b"!downloadSources!"  # abstract-level's sublevel encoding: !<name>!<key>
UA = "hydralauncher-sources-sync"  # urllib's default User-Agent is refused by some CDNs


def request(url, body=None):
    req = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": UA},
        method="GET" if body is None else "POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def catalog_urls(query):
    """Every page of the library.hydra.wiki catalog the query selects, NSFW always left out."""
    parts = urllib.parse.urlsplit(query)
    params = dict(urllib.parse.parse_qsl(parts.query))
    urls, page, pages = [], 1, 1
    while page <= pages:
        params["page"] = str(page)
        answer = request(parts._replace(query=urllib.parse.urlencode(params)).geturl())
        urls += [s["url"] for s in answer["sources"] if "NSFW" not in s["status"]]
        pages, page = answer["totalPages"], page + 1
    return urls


def main():
    db_path, config_file = sys.argv[1], sys.argv[2]
    with open(config_file) as f:
        config = json.load(f)

    # Before the DB: a catalog that does not answer must not read as "declare nothing" and wipe it.
    try:
        declared = catalog_urls(config["catalog"]) + config["extra"]
    except Exception as e:
        print(f"hydralauncher-sources-sync: the catalog did not answer, skipped: {e}", file=sys.stderr)
        return 1

    try:
        db = plyvel.DB(db_path, create_if_missing=True)
    except plyvel.IOError:
        # LevelDB's LOCK: the app is open, and a second launch only focuses it. Next launch, then.
        print("hydralauncher-sources-sync: Hydra is running, skipped", file=sys.stderr)
        return 0

    failed = 0
    with db:
        current = {json.loads(v)["url"]: k for k, v in db.iterator(prefix=PREFIX)}

        for url, key in current.items():
            if url not in declared:
                db.delete(key)
                print(f"hydralauncher-sources-sync: removed {url}")

        for url in declared:
            if url in current:
                continue
            try:
                source = request(f"{API}/download-sources", {"url": url})
            except Exception as e:  # one dead source must not keep the others out
                print(f"hydralauncher-sources-sync: {url}: {e}", file=sys.stderr)
                failed += 1
                continue
            source.update(isRemote=True, createdAt=datetime.now(timezone.utc).isoformat())
            db.put(PREFIX + str(source["id"]).encode(), json.dumps(source).encode())
            print(f"hydralauncher-sources-sync: added {url}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
