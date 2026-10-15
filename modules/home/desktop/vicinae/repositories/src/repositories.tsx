import {
  Action,
  ActionPanel,
  Cache,
  Color,
  getPreferenceValues,
  Icon,
  Image,
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
  // The account or group the repository lives under, and its avatar.
  owner: string;
  ownerUrl: string;
  ownerAvatar: string;
  visibility: string;
  access: string; // my role on it, from the token's permissions
  isFork: boolean;
  isArchived: boolean;
  language: string;
  defaultBranch: string;
  stars: number;
  forks: number;
  topics: string[];
  createdAt: string;
  updatedAt: string;
};

type GithubRepo = {
  full_name: string;
  name: string;
  owner: { login: string; html_url: string; avatar_url: string };
  description: string | null;
  html_url: string;
  ssh_url: string;
  visibility?: string;
  private: boolean;
  fork: boolean;
  archived: boolean;
  language: string | null;
  default_branch: string;
  stargazers_count: number;
  forks_count: number;
  topics?: string[];
  permissions?: { admin?: boolean; maintain?: boolean; push?: boolean; triage?: boolean };
  created_at: string;
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
  namespace: { full_path: string; web_url: string; avatar_url: string | null };
  forked_from_project?: unknown;
  archived?: boolean;
  default_branch?: string | null;
  star_count: number;
  forks_count: number;
  topics?: string[];
  permissions?: {
    project_access: { access_level: number } | null;
    group_access: { access_level: number } | null;
  };
  created_at: string;
  last_activity_at: string;
};

const cache = new Cache();
const CACHE_KEY = "repos-v2";
const DETAIL_KEY = "show-detail";

const prefs = getPreferenceValues<Preferences>();
const owners = (prefs.githubOwners ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);
const gitlabBase = (prefs.gitlabUrl ?? "").replace(/\/+$/, "");
const gitlabTitle = prefs.gitlabTitle || "GitLab";

const PLATFORM: Record<Source, { title: string; icon: Image.ImageLike }> = {
  github: { title: "GitHub", icon: { source: Icon.Github, tintColor: Color.PrimaryText } },
  gitlab: { title: "GitLab", icon: { source: Icon.Gitlab, tintColor: Color.Orange } },
};

// GitLab's access levels, as its UI names them.
const GITLAB_ROLES: Record<number, string> = {
  5: "Minimal access",
  10: "Guest",
  15: "Planner",
  20: "Reporter",
  30: "Developer",
  40: "Maintainer",
  50: "Owner",
};

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

function githubAccess(p: GithubRepo["permissions"]): string {
  if (!p) return "";
  if (p.admin) return "Admin";
  if (p.maintain) return "Maintain";
  if (p.push) return "Write";
  if (p.triage) return "Triage";
  return "Read";
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
    // The token's copy carries my permissions; a public listing seen first must not hide them.
    const seen = byName.get(r.full_name.toLowerCase());
    if (seen?.access) continue;
    byName.set(r.full_name.toLowerCase(), {
      id: `github:${r.full_name}`,
      source: "github",
      section: owners.find((o) => o.toLowerCase() === owner.toLowerCase()) ?? owner,
      name: r.name,
      fullName: r.full_name,
      description: r.description ?? "",
      url: r.html_url,
      sshUrl: r.ssh_url,
      owner,
      ownerUrl: r.owner.html_url,
      ownerAvatar: r.owner.avatar_url,
      visibility: r.visibility ?? (r.private ? "private" : "public"),
      access: githubAccess(r.permissions),
      isFork: r.fork,
      isArchived: r.archived,
      language: r.language ?? "",
      defaultBranch: r.default_branch,
      stars: r.stargazers_count,
      forks: r.forks_count,
      topics: r.topics ?? [],
      createdAt: r.created_at,
      updatedAt: r.pushed_at ?? r.updated_at,
    });
  }
  return [...byName.values()];
}

// GitLab hands back avatars as instance-relative paths when they are uploads.
function absolute(url: string | null): string {
  if (!url) return "";
  return url.startsWith("/") ? `${gitlabBase}${url}` : url;
}

async function fetchGitlab(): Promise<Repo[]> {
  if (!gitlabBase) return [];
  const headers: Record<string, string> = {};
  if (prefs.gitlabTokenFile) headers["PRIVATE-TOKEN"] = readFileSync(prefs.gitlabTokenFile, "utf8").trim();
  const out: Repo[] = [];
  for (let page: string | null = "1"; page; ) {
    const res: Response = await fetch(
      `${gitlabBase}/api/v4/projects?membership=true&order_by=last_activity_at&per_page=100&page=${page}`,
      { headers, signal: AbortSignal.timeout(8000) },
    );
    if (!res.ok) throw new Error(`GitLab ${res.status}`);
    for (const p of (await res.json()) as GitlabProject[]) {
      const level = Math.max(
        p.permissions?.project_access?.access_level ?? 0,
        p.permissions?.group_access?.access_level ?? 0,
      );
      out.push({
        id: `gitlab:${p.id}`,
        source: "gitlab",
        section: gitlabTitle,
        name: p.name,
        fullName: p.path_with_namespace,
        description: p.description ?? "",
        url: p.web_url,
        sshUrl: p.ssh_url_to_repo,
        owner: p.namespace.full_path,
        ownerUrl: p.namespace.web_url,
        ownerAvatar: absolute(p.namespace.avatar_url),
        visibility: p.visibility,
        access: GITLAB_ROLES[level] ?? "",
        isFork: Boolean(p.forked_from_project),
        isArchived: Boolean(p.archived),
        language: "",
        defaultBranch: p.default_branch ?? "",
        stars: p.star_count,
        forks: p.forks_count,
        topics: p.topics ?? [],
        createdAt: p.created_at,
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

const day = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium" });

function avatar(r: Repo): Image.ImageLike {
  if (!r.ownerAvatar) return { source: Icon.Person, tintColor: Color.SecondaryText };
  return { source: r.ownerAvatar, fallback: Icon.Person, mask: Image.Mask.Circle };
}

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function Detail({ repo: r }: { repo: Repo }) {
  const isPublic = r.visibility === "public";
  return (
    <List.Item.Detail
      markdown={`## ${r.fullName}\n\n${r.description || "_No description._"}`}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label
            title="Platform"
            text={r.source === "gitlab" ? `GitLab · ${new URL(gitlabBase).host}` : "GitHub"}
            icon={PLATFORM[r.source].icon}
          />
          <List.Item.Detail.Metadata.Label title="Owner" text={r.owner} icon={avatar(r)} />
          {r.access ? <List.Item.Detail.Metadata.Label title="My access" text={r.access} icon={Icon.Person} /> : null}
          <List.Item.Detail.Metadata.TagList title="Visibility">
            <List.Item.Detail.Metadata.TagList.Item
              text={capitalize(r.visibility)}
              icon={isPublic ? Icon.LockUnlocked : Icon.Lock}
              color={isPublic ? Color.Green : Color.Yellow}
            />
            {r.isArchived ? <List.Item.Detail.Metadata.TagList.Item text="Archived" color={Color.Orange} /> : null}
            {r.isFork ? <List.Item.Detail.Metadata.TagList.Item text="Fork" color={Color.Purple} /> : null}
          </List.Item.Detail.Metadata.TagList>
          <List.Item.Detail.Metadata.Separator />
          {r.language ? <List.Item.Detail.Metadata.Label title="Language" text={r.language} icon={Icon.Code} /> : null}
          {r.defaultBranch ? (
            <List.Item.Detail.Metadata.Label title="Default branch" text={r.defaultBranch} icon={Icon.Tag} />
          ) : null}
          <List.Item.Detail.Metadata.Label title="Stars" text={String(r.stars)} icon={Icon.Star} />
          <List.Item.Detail.Metadata.Label title="Forks" text={String(r.forks)} />
          {r.topics.length > 0 ? (
            <List.Item.Detail.Metadata.TagList title="Topics">
              {r.topics.map((t) => (
                <List.Item.Detail.Metadata.TagList.Item key={t} text={t} color={Color.Blue} />
              ))}
            </List.Item.Detail.Metadata.TagList>
          ) : null}
          <List.Item.Detail.Metadata.Separator />
          <List.Item.Detail.Metadata.Label title="Last activity" text={`${ago(r.updatedAt)}`} />
          <List.Item.Detail.Metadata.Label title="Created" text={day.format(new Date(r.createdAt))} />
          <List.Item.Detail.Metadata.Link title="Link" target={r.url} text={r.url.replace(/^https:\/\//, "")} />
        </List.Item.Detail.Metadata>
      }
    />
  );
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
  const [showDetail, setShowDetail] = useState(() => cache.get(DETAIL_KEY) !== "false");

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

  const toggleDetail = () =>
    setShowDetail((shown) => {
      cache.set(DETAIL_KEY, String(!shown));
      return !shown;
    });

  const order = [...owners, gitlabTitle];
  const sections = [...new Set(repos.map((r) => r.section))].sort((a, b) => {
    const ia = order.indexOf(a);
    const ib = order.indexOf(b);
    return (ia < 0 ? order.length : ia) - (ib < 0 ? order.length : ib) || a.localeCompare(b);
  });

  return (
    <List isLoading={isLoading} isShowingDetail={showDetail} searchBarPlaceholder="Filter repositories by name...">
      {sections.map((section) => {
        const items = repos.filter((r) => r.section === section);
        return (
          <List.Section
            key={section}
            title={section}
            subtitle={`${PLATFORM[items[0].source].title} · ${items.length}`}
          >
            {items
              .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
              .map((r) => (
                <List.Item
                  key={r.id}
                  id={r.id}
                  title={r.name}
                  subtitle={showDetail ? undefined : r.description}
                  keywords={[r.fullName, r.owner, PLATFORM[r.source].title]}
                  icon={PLATFORM[r.source].icon}
                  detail={<Detail repo={r} />}
                  accessories={[
                    ...(r.visibility !== "public" ? [{ icon: Icon.Lock, tooltip: capitalize(r.visibility) }] : []),
                    ...(showDetail
                      ? []
                      : [
                          ...(r.isArchived ? [{ tag: { value: "archived", color: Color.Orange } }] : []),
                          ...(r.isFork ? [{ tag: { value: "fork", color: Color.Purple } }] : []),
                          { text: { value: ago(r.updatedAt), color: Color.SecondaryText }, tooltip: r.updatedAt },
                        ]),
                    { icon: avatar(r), tooltip: r.owner },
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
                      <Action.OpenInBrowser
                        title={`Open ${r.owner} in Browser`}
                        url={r.ownerUrl}
                        icon={Icon.Person}
                      />
                      <Action
                        title={showDetail ? "Hide Details" : "Show Details"}
                        icon={Icon.AppWindowSidebarRight}
                        shortcut={{ modifiers: ["ctrl"], key: "d" }}
                        onAction={toggleDetail}
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
        );
      })}
    </List>
  );
}
