// Package snippets provides code snippets to type, either from a bundled
// local bank (default, no network needed) or fetched live from a random
// popular GitHub repository for the chosen language.
package snippets

import (
	"bufio"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Language identifies a supported practice language.
type Language string

const (
	Go         Language = "go"
	Python     Language = "python"
	JavaScript Language = "javascript"
)

// Languages lists all supported languages in display order.
var Languages = []Language{Go, Python, JavaScript}

// Label returns a human-friendly display name for a language.
func (l Language) Label() string {
	switch l {
	case Go:
		return "Go"
	case Python:
		return "Python"
	case JavaScript:
		return "JavaScript"
	default:
		return string(l)
	}
}

// Extension returns the file extension GitHub search should filter by.
func (l Language) Extension() string {
	switch l {
	case Go:
		return "go"
	case Python:
		return "py"
	case JavaScript:
		return "js"
	default:
		return ""
	}
}

// Snippet is a single block of code to type, with metadata about its origin.
type Snippet struct {
	Language Language
	Source   string // "local" or a repo path like "golang/go"
	Path     string // file path within the source, for local bank entries
	Code     string
}

//go:embed bank/*
var bankFS embed.FS

// localBank caches parsed snippets per language so we only read disk once.
var localBank = map[Language][]Snippet{}

// LoadLocal returns all bundled local snippets for a language, reading and
// caching them from the embedded bank on first use.
func LoadLocal(lang Language) ([]Snippet, error) {
	if cached, ok := localBank[lang]; ok {
		return cached, nil
	}

	dir := "bank/" + string(lang)
	entries, err := bankFS.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("no local snippets bundled for %s: %w", lang, err)
	}

	var out []Snippet
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		data, err := bankFS.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		code := strings.TrimRight(string(data), "\n")
		if code == "" {
			continue
		}
		// Normalize tabs to spaces so typed Tab (4 spaces) matches.
		code = strings.ReplaceAll(code, "\t", "    ")
		// Go source files in the bank are stored with a ".go.txt" extension
		// so `go build` does not try to compile them as part of this module
		// (they have no package clause — they're snippets, not packages).
		// Strip the trailing ".txt" here so the displayed path still reads
		// as a normal .go filename.
		displayName := strings.TrimSuffix(e.Name(), ".txt")
		out = append(out, Snippet{
			Language: lang,
			Source:   "local",
			Path:     displayName,
			Code:     code,
		})
	}

	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	localBank[lang] = out
	return out, nil
}

// RandomLocal returns one random snippet from the local bank for a language.
func RandomLocal(lang Language, r *rand.Rand) (Snippet, error) {
	all, err := LoadLocal(lang)
	if err != nil {
		return Snippet{}, err
	}
	if len(all) == 0 {
		return Snippet{}, fmt.Errorf("local snippet bank for %s is empty", lang)
	}
	return all[r.Intn(len(all))], nil
}

// --- GitHub fetching -------------------------------------------------------
//
// We use GitHub's public API to find a real source file in a well-known
// repository for the chosen language, then download its raw contents. This
// is intentionally simple: a small curated list of seed repositories per
// language (to keep results relevant and avoid noisy search-API quota
// usage), one random pick, one random file, trimmed to a reasonable typing
// length.

// seedRepos are well-known, idiomatic repos to pull sample files from.
// Kept short and curated rather than doing a fully open code search, so
// fetched snippets stay representative of clean, real-world code.
var seedRepos = map[Language][]string{
	Go: {
		"golang/example",
		"gin-gonic/gin",
		"spf13/cobra",
	},
	Python: {
		"psf/requests",
		"pallets/flask",
		"python/cpython",
	},
	JavaScript: {
		"lodash/lodash",
		"expressjs/express",
		"axios/axios",
	},
}

type ghTreeResponse struct {
	Tree []ghTreeEntry `json:"tree"`
}

type ghTreeEntry struct {
	Path string `json:"path"`
	Type string `json:"type"`
	Size int    `json:"size"`
}

type ghRepoResponse struct {
	DefaultBranch string `json:"default_branch"`
}

var httpClient = &http.Client{Timeout: 10 * time.Second}

func ghGet(url string, out any) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "typetui")

	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("github api %s: status %d: %s", url, resp.StatusCode, string(body))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

// FetchRandomGitHub fetches a random source file for lang from one of the
// curated seed repositories and returns it as a Snippet. It returns an error
// if the network is unavailable or no suitable file can be found — callers
// should fall back to RandomLocal in that case.
func FetchRandomGitHub(lang Language, r *rand.Rand) (Snippet, error) {
	repos := seedRepos[lang]
	if len(repos) == 0 {
		return Snippet{}, fmt.Errorf("no seed repositories configured for %s", lang)
	}

	// Try a few repos in random order in case one has no matching files or
	// the request fails, before giving up entirely.
	order := r.Perm(len(repos))
	ext := "." + lang.Extension()

	var lastErr error
	for _, idx := range order {
		repo := repos[idx]

		var repoInfo ghRepoResponse
		if err := ghGet("https://api.github.com/repos/"+repo, &repoInfo); err != nil {
			lastErr = err
			continue
		}
		branch := repoInfo.DefaultBranch
		if branch == "" {
			branch = "main"
		}

		var tree ghTreeResponse
		treeURL := fmt.Sprintf("https://api.github.com/repos/%s/git/trees/%s?recursive=1", repo, branch)
		if err := ghGet(treeURL, &tree); err != nil {
			lastErr = err
			continue
		}

		var candidates []ghTreeEntry
		for _, entry := range tree.Tree {
			if entry.Type != "blob" {
				continue
			}
			if !strings.HasSuffix(entry.Path, ext) {
				continue
			}
			// Skip test files, vendored code, and minified/generated output
			// so practice snippets stay readable and idiomatic.
			lower := strings.ToLower(entry.Path)
			if strings.Contains(lower, "test") ||
				strings.Contains(lower, "vendor/") ||
				strings.Contains(lower, "node_modules/") ||
				strings.Contains(lower, ".min.") ||
				strings.Contains(lower, "dist/") {
				continue
			}
			// Keep file size in a range likely to produce a good 10-30 line
			// snippet once trimmed below.
			if entry.Size < 200 || entry.Size > 8000 {
				continue
			}
			candidates = append(candidates, entry)
		}

		if len(candidates) == 0 {
			lastErr = fmt.Errorf("no suitable %s files found in %s", ext, repo)
			continue
		}

		chosen := candidates[r.Intn(len(candidates))]
		rawURL := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, branch, chosen.Path)

		code, err := fetchAndTrim(rawURL)
		if err != nil {
			lastErr = err
			continue
		}
		if code == "" {
			lastErr = fmt.Errorf("file %s in %s was empty after trimming", chosen.Path, repo)
			continue
		}

		return Snippet{
			Language: lang,
			Source:   repo,
			Path:     chosen.Path,
			Code:     code,
		}, nil
	}

	return Snippet{}, fmt.Errorf("could not fetch a github snippet for %s: %w", lang, lastErr)
}

// fetchAndTrim downloads a raw file and trims it to a reasonable typing
// length: skips leading license/comment banners and blank lines, then takes
// a contiguous block of up to maxLines non-trivial lines.
func fetchAndTrim(url string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "typetui")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("raw fetch %s: status %d", url, resp.StatusCode)
	}

	const maxLines = 28
	const maxLineLen = 100

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var lines []string
	skippingBanner := true

	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		if skippingBanner {
			if trimmed == "" {
				continue
			}
			if strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "#") ||
				strings.HasPrefix(trimmed, "/*") || strings.HasPrefix(trimmed, "*") ||
				strings.HasPrefix(trimmed, "*/") {
				continue
			}
			skippingBanner = false
		}

		if len(line) > maxLineLen {
			line = line[:maxLineLen]
		}
		// Normalize tabs to spaces for consistent column widths in the UI.
		line = strings.ReplaceAll(line, "\t", "    ")

		lines = append(lines, line)
		if len(lines) >= maxLines {
			break
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}

	// Trim trailing blank lines.
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}

	if len(lines) < 4 {
		return "", fmt.Errorf("file too short after trimming banner/comments")
	}

	return strings.Join(lines, "\n"), nil
}
