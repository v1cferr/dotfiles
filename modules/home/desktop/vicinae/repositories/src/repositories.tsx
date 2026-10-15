import {
  Action,
  ActionPanel,
  Cache,
  Color,
  getPreferenceValues,
  Icon,
  Keyboard,
  List,
  showToast,
  Toast,
} from "@vicinae/api";
import { readFileSync } from "node:fs";
import { useEffect, useState } from "react";

type Preferences = {
  githubToken?: string;
  githubOwners?: string;
  gitlabUrl?: string;
  gitlabTitle?: string;
  gitlabTokenFile?: string;
};

type Source = "github" | "gitlab";

type Repo = {
  id: string;
  source: Source;
  section: string;
  name: string;
  fullName: string;
  description: string;
  url: string;
  sshUrl: string;
  isPrivate: boolean;
  isFork: boolean;
  isArchived: boolean;
  updatedAt: string;
};

type GithubRepo = {
  full_name: string;
  name: string;
  owner: { login: string };
  description: string | null;
  html_url: string;
  ssh_url: string;
  private: boolean;
  fork: boolean;
  archived: boolean;
  pushed_at: string | null;
  updated_at: string;
};

type GitlabProject = {
  id: number;
  name: string;
  path_with_namespace: string;
  description: string | null;
  web_url: string;
  ssh_url_to_repo: string;
  visibility: string;
  forked_from_project?: unknown;
  archived?: boolean;
  last_activity_at: string;
};

const cache = new Cache();
const CACHE_KEY = "repos-v1";

const prefs = getPreferenceValues<Preferences>();
const owners = (prefs.githubOwners ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);
const gitlabTitle = prefs.gitlabTitle || "GitLab";

// Follows the RFC 8288 Link header GitHub paginates with.
function nextLink(header: string | null): string | null {
  const match = header?.match(/<([^>]+)>;\s*rel="next"/);
  return match ? match[1] : null;
}

async function githubPages(url: string): Promise<GithubRepo[]> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
  if (prefs.githubToken) headers.Authorization = `Bearer ${prefs.githubToken}`;
  const out: GithubRepo[] = [];
  for (let next: string | null = url; next; ) {
    const res = await fetch(next, { headers });
    if (!res.ok) throw new Error(`GitHub ${res.status} on ${new URL(next).pathname}`);
    out.push(...((await res.json()) as GithubRepo[]));
    next = nextLink(res.headers.get("link"));
  }
  return out;
}

// What the token can read (the private repos, mine or shared with me) plus each account's public
// ones, which also covers accounts I am not a collaborator of.
async function fetchGithub(): Promise<Repo[]> {
  const api = "https://api.github.com";
  const lists = await Promise.all([
    prefs.githubToken
      ? githubPages(`${api}/user/repos?affiliation=owner,collaborator,organization_member&per_page=100`)
      : Promise.resolve([]),
    ...owners.map((o) => githubPages(`${api}/users/${encodeURIComponent(o)}/repos?type=owner&per_page=100`)),
  ]);
  const wanted = new Set(owners.map((o) => o.toLowerCase()));
  const byName = new Map<string, Repo>();
  for (const r of lists.flat()) {
    const owner = r.owner.login;
    if (wanted.size > 0 && !wanted.has(owner.toLowerCase())) continue;
    byName.set(r.full_name.toLowerCase(), {
      id: `github:${r.full_name}`,
      source: "github",
      section: owners.find((o) => o.toLowerCase() === owner.toLowerCase()) ?? owner,
      name: r.name,
      fullName: r.full_name,
      description: r.description ?? "",
      url: r.html_url,
      sshUrl: r.ssh_url,
      isPrivate: r.private,
      isFork: r.fork,
      isArchived: r.archived,
      updatedAt: r.pushed_at ?? r.updated_at,
    });
  }
  return [...byName.values()];
}

async function fetchGitlab(): Promise<Repo[]> {
  const base = (prefs.gitlabUrl ?? "").replace(/\/+$/, "");
  if (!base) return [];
  const headers: Record<string, string> = {};
  if (prefs.gitlabTokenFile) headers["PRIVATE-TOKEN"] = readFileSync(prefs.gitlabTokenFile, "utf8").trim();
  const out: Repo[] = [];
  for (let page: string | null = "1"; page; ) {
    const res: Response = await fetch(
      `${base}/api/v4/projects?membership=true&order_by=last_activity_at&per_page=100&page=${page}`,
      { headers, signal: AbortSignal.timeout(8000) },
    );
    if (!res.ok) throw new Error(`GitLab ${res.status}`);
    for (const p of (await res.json()) as GitlabProject[]) {
      out.push({
        id: `gitlab:${p.id}`,
        source: "gitlab",
        section: gitlabTitle,
        name: p.name,
        fullName: p.path_with_namespace,
        description: p.description ?? "",
        url: p.web_url,
        sshUrl: p.ssh_url_to_repo,
        isPrivate: p.visibility !== "public",
        isFork: Boolean(p.forked_from_project),
        isArchived: Boolean(p.archived),
        updatedAt: p.last_activity_at,
      });
    }
    page = res.headers.get("x-next-page") || null;
  }
  return out;
}

const relative = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
const UNITS: [Intl.RelativeTimeFormatUnit, number][] = [
  ["year", 365 * 24 * 3600],
  ["month", 30 * 24 * 3600],
  ["week", 7 * 24 * 3600],
  ["day", 24 * 3600],
  ["hour", 3600],
  ["minute", 60],
];

// "3 days ago": when the repository last saw a push.
function ago(iso: string): string {
  const seconds = (Date.parse(iso) - Date.now()) / 1000;
  for (const [unit, size] of UNITS) {
    if (Math.abs(seconds) >= size) return relative.format(Math.round(seconds / size), unit);
  }
  return "just now";
}

function readCache(): Repo[] {
  try {
    return JSON.parse(cache.get(CACHE_KEY) ?? "[]") as Repo[];
  } catch {
    return [];
  }
}

export default function Repositories() {
  const [repos, setRepos] = useState<Repo[]>(readCache);
  const [isLoading, setIsLoading] = useState(true);
  const [reloads, setReloads] = useState(0);

  // Shows the cached list at once, then refreshes it. A source that fails (GitLab without the
  // VPN) keeps its cached entries and says so in a toast.
  useEffect(() => {
    let alive = true;
    setIsLoading(true);
    (async () => {
      const results = await Promise.allSettled([fetchGithub(), fetchGitlab()]);
      if (!alive) return;
      const sources: Source[] = ["github", "gitlab"];
      const previous = readCache();
      const merged: Repo[] = [];
      const failures: string[] = [];
      results.forEach((result, i) => {
        if (result.status === "fulfilled") merged.push(...result.value);
        else {
          merged.push(...previous.filter((r) => r.source === sources[i]));
          failures.push(result.reason instanceof Error ? result.reason.message : String(result.reason));
        }
      });
      cache.set(CACHE_KEY, JSON.stringify(merged));
      setRepos(merged);
      setIsLoading(false);
      if (failures.length > 0) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Some repositories could not be refreshed",
          message: failures.join("; "),
        });
      }
    })();
    return () => {
      alive = false;
    };
  }, [reloads]);

  const order = [...owners, gitlabTitle];
  const sections = [...new Set(repos.map((r) => r.section))].sort((a, b) => {
    const ia = order.indexOf(a);
    const ib = order.indexOf(b);
    return (ia < 0 ? order.length : ia) - (ib < 0 ? order.length : ib) || a.localeCompare(b);
  });

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Filter repositories by name...">
      {sections.map((section) => (
        <List.Section key={section} title={section}>
          {repos
            .filter((r) => r.section === section)
            .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
            .map((r) => (
              <List.Item
                key={r.id}
                id={r.id}
                title={r.name}
                subtitle={r.description}
                keywords={[r.fullName]}
                icon={r.isPrivate ? Icon.Lock : Icon.Book}
                accessories={[
                  ...(r.isArchived ? [{ tag: { value: "archived", color: Color.Orange } }] : []),
                  ...(r.isFork ? [{ tag: { value: "fork", color: Color.Purple } }] : []),
                  { text: { value: ago(r.updatedAt), color: Color.SecondaryText }, tooltip: r.updatedAt },
                ]}
                actions={
                  <ActionPanel>
                    <Action.OpenInBrowser title="Open in Browser" url={r.url} />
                    <Action.CopyToClipboard title="Copy SSH Clone URL" content={r.sshUrl} />
                    <Action.CopyToClipboard
                      title="Copy URL"
                      content={r.url}
                      shortcut={Keyboard.Shortcut.Common.Copy}
                    />
                    <Action
                      title="Refresh"
                      icon={Icon.ArrowClockwise}
                      shortcut={Keyboard.Shortcut.Common.Refresh}
                      onAction={() => setReloads((n) => n + 1)}
                    />
                  </ActionPanel>
                }
              />
            ))}
        </List.Section>
      ))}
    </List>
  );
}
