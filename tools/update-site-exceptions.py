"""Refresh the site-exception list from DuckDuckGo's privacy configuration and apply it.

Some sites break when they receive the GPC/DNT signals (login errors, endless reloads,
buttons that stop working). DuckDuckGo keeps a list of them, with a reason for each, in
features/gpc.json of duckduckgo/privacy-configuration (Apache-2.0). GPC Switch ships a
snapshot of that list and stays silent on those sites. The snapshot is
`extension/rules/site-exceptions.json`; the header rules and the host list in signal.js
are generated from it, and the app and popup read the same file, so the four
can never disagree.

Nothing fetches at build time on purpose: a build that reaches for the network is not
reproducible, and an archive would carry whatever the list said that minute. Run this
deliberately, review the diff, commit.

Usage:
  uv run python3 tools/update-site-exceptions.py            fetch, snapshot, apply
  uv run python3 tools/update-site-exceptions.py --apply    re-apply the snapshot, no network
  uv run python3 tools/update-site-exceptions.py --check    exit 1 if the derived files are stale
"""

import datetime as dt
import ipaddress
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / "extension" / "rules" / "site-exceptions.json"
RULES = ROOT / "extension" / "rules" / "privacy-signal-headers.json"
SIGNAL = ROOT / "extension" / "signal.js"
SIGNAL_BLOCK = re.compile(r"(  // BEGIN EXCLUDED HOSTS\n).*?(  // END EXCLUDED HOSTS\n)", re.S)

SOURCE = "https://github.com/duckduckgo/privacy-configuration/blob/main/features/gpc.json"
RAW = "https://raw.githubusercontent.com/duckduckgo/privacy-configuration/main/features/gpc.json"
LICENSE = "Apache-2.0"

# A rule with a bad domain fails compilation of the whole ruleset, and Safari only
# logs that to the system log, so be strict about what gets written.
HOST_RE = re.compile(r"^[a-z0-9-]+(\.[a-z0-9-]+)+$")
MAX_SITES = 500


def fetch_sites() -> list[dict]:
    with urllib.request.urlopen(RAW, timeout=30) as response:
        config = json.load(response)
    if config.get("state") != "enabled":
        sys.exit(f"error: the gpc feature is not 'enabled' in {RAW}; look before trusting its list")
    exceptions = config.get("exceptions")
    if not isinstance(exceptions, list) or not exceptions:
        sys.exit(f"error: {RAW} has no exceptions list")
    return exceptions


def is_ip(domain: str) -> bool:
    try:
        ipaddress.ip_address(domain)
        return True
    except ValueError:
        return False


def validate(sites: list[dict]) -> list[dict]:
    by_domain: dict[str, str] = {}
    for site in sites:
        if not (isinstance(site, dict) and isinstance(site.get("domain"), str)
                and isinstance(site.get("reason", ""), str)):
            sys.exit(f"error: an exceptions entry changed shape (expected domain/reason strings): {site!r}")
        domain = site["domain"].strip().lower()
        reason = site.get("reason", "").strip()
        # HOST_RE needs a dot, so 'localhost' (which the test server needs) never passes.
        if not HOST_RE.match(domain) or is_ip(domain):
            sys.exit(f"error: refusing a domain that is not a plain lowercase domain: {domain!r}")
        by_domain[domain] = reason
    if not 1 <= len(by_domain) <= MAX_SITES:
        sys.exit(f"error: {len(by_domain)} sites is outside the sane range 1..{MAX_SITES}")
    return [{"domain": d, "reason": by_domain[d]} for d in sorted(by_domain)]


def read_json(path: Path):
    with path.open() as f:
        return json.load(f)


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")
    print(path.relative_to(ROOT))


def derived(sites: list[dict]) -> tuple[list, str]:
    """The rules file and signal.js as they should be for these sites."""
    hosts = [s["domain"] for s in sites]
    rules = read_json(RULES)
    for rule in rules:
        ops = {h["operation"] for h in rule["action"].get("requestHeaders", [])}
        if ops == {"set"}:
            # Add the signals unless the top-level page is an excluded site.
            rule["condition"]["excludedDomains"] = list(hosts)
        elif ops == {"remove"}:
            # A redirect into an excluded site keeps the headers set on the first hop;
            # strip them from documents whose own URL is an excluded site.
            rule["condition"]["requestDomains"] = list(hosts)
        else:
            sys.exit(f"error: rule {rule.get('id')} mixes header operations: {sorted(ops)}")
    listing = "".join(f"    {json.dumps(h)},\n" for h in hosts)
    block = f"  var EXCLUDED_HOSTS = [\n{listing}  ];\n"
    signal_text = SIGNAL.read_text()
    if not SIGNAL_BLOCK.search(signal_text):
        sys.exit(f"error: {SIGNAL.name} has no BEGIN/END EXCLUDED HOSTS block")
    signal = SIGNAL_BLOCK.sub(lambda m: m.group(1) + block + m.group(2), signal_text)
    return rules, signal


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    if mode not in ("fetch", "--apply", "--check"):
        sys.exit(__doc__)

    if mode == "fetch":
        sites = validate(fetch_sites())
        snapshot = {"source": SOURCE, "license": LICENSE,
                    "fetched": dt.date.today().isoformat(), "sites": sites}
        write_json(SNAPSHOT, snapshot)
    else:
        snapshot = read_json(SNAPSHOT)
        sites = validate(snapshot["sites"])
        snapshot["sites"] = sites

    rules, signal = derived(sites)
    if mode == "--check":
        # The app, popup and badge read the snapshot as is, so it must already be normal.
        stale = [p.relative_to(ROOT) for p, want in ((SNAPSHOT, snapshot), (RULES, rules))
                 if read_json(p) != want]
        if SIGNAL.read_text() != signal:
            stale.append(SIGNAL.relative_to(ROOT))
        if stale:
            sys.exit(f"error: out of date with {SNAPSHOT.name}: {', '.join(map(str, stale))}")
        print(f"ok: {len(sites)} site exceptions applied consistently")
        return

    if mode == "--apply":
        write_json(SNAPSHOT, snapshot)
    write_json(RULES, rules)
    SIGNAL.write_text(signal)
    print(SIGNAL.relative_to(ROOT))
    print(f"{len(sites)} site exceptions applied")


if __name__ == "__main__":
    main()
