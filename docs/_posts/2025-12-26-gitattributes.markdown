---
layout: post
title:  "Understanding .gitattributes: controlling how Git treats your files"
date:   2025-12-26 14:58:56 -0000
categories: git
image: "/assets/images/2025-12-26-gitattributes/banner.png"
---

Most teams are familiar with `.gitignore`, but far fewer make deliberate use of [`.gitattributes`](https://git-scm.com/docs/gitattributes).
This is unfortunate, because [`.gitattributes`](https://git-scm.com/docs/gitattributes) plays a critical role in **how Git interprets files**, not merely whether they are tracked.

Used correctly, [`.gitattributes`](https://git-scm.com/docs/gitattributes) improves:

* Cross-platform consistency
* Diff and merge quality
* Repository cleanliness
* Tooling reliability (CI, formatters, linters)
* Binary and large-file handling

This article explains what [`.gitattributes`](https://git-scm.com/docs/gitattributes) does and presents practical rules that should be considered in professional repositories.

---

## What `.gitattributes` Is

[`.gitattributes`](https://git-scm.com/docs/gitattributes) defines **path-based rules** that instruct Git how to:

* Normalize line endings
* Classify files as text or binary
* Generate diffs
* Resolve merges
* Apply filters (e.g., Git LFS)

In short:

> `.gitignore` controls *whether* files are tracked.
> `.gitattributes` controls *how* tracked files are handled.

Rules can be defined globally, per directory, or per repository, and they are versioned alongside the codebase.

---

## Line Ending Normalization

Line ending inconsistencies are one of the most common sources of unnecessary diffs in multi-platform teams.

### Recommended Baseline

```gitattributes
* text=auto
```

This configuration tells Git to:

* Store all text files in the repository using LF
* Convert line endings appropriately in the working tree based on the operating system

This approach avoids relying on individual developer configuration such as `core.autocrlf`, which is error-prone and inconsistent across environments.

### Enforcing Explicit Line Endings

For repositories that require strict control:

```gitattributes
*.go   text eol=lf
*.sh   text eol=lf
*.sql  text eol=lf
*.ps1  text eol=crlf
*.bat  text eol=crlf
```

This ensures deterministic behavior regardless of platform or editor configuration.

---

## Explicitly Declaring Binary Files

Git attempts to infer whether a file is text or binary.
This inference is not always correct and can lead to confusing diffs or merge behavior.

### Best Practice

Declare binary files explicitly:

```gitattributes
*.png  binary
*.jpg  binary
*.pdf  binary
*.zip  binary
*.mp4  binary
```

Benefits:

* Prevents meaningless diff output
* Avoids accidental merge conflicts
* Improves performance when working with large assets

---

## Improving Diffs for Specific File Types

Some file formats benefit from custom diff behavior.

### Marking Files as Non-Diffable

```gitattributes
*.lock  -diff
*.min.js -diff
```

This reduces noise in pull requests when diffs provide little or no value.

### Language-Aware Diffs

Git supports language-specific diff drivers:

```gitattributes
*.go   diff=golang
*.md   diff=markdown
```

This improves readability when reviewing changes.

---

## Controlling Merge Behavior

Not all files should be merged.

### Favoring One Side During Merges

For generated or machine-specific files:

```gitattributes
*.generated merge=ours
```

This ensures Git always prefers the current branch’s version, avoiding pointless conflicts.

### Disabling Merges Entirely

```gitattributes
*.lock binary
```

Binary files cannot be merged meaningfully and should always be treated as such.

---

## Git LFS Integration

[`.gitattributes`](https://git-scm.com/docs/gitattributes) is the authoritative way to enable Git LFS:

```gitattributes
*.psd filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text
```

This keeps large files out of the main Git object store while maintaining correct behavior.

---

## A Sensible Default `.gitattributes`

For most professional repositories, the following is a strong starting point:

```gitattributes
* text=auto

# Source code
*.go   text eol=lf
*.sh   text eol=lf
*.sql  text eol=lf

# Windows scripts
*.bat  text eol=crlf
*.ps1  text eol=crlf

# Binary files
*.png  binary
*.jpg  binary
*.pdf  binary
*.zip  binary
```

This configuration eliminates an entire class of platform-specific issues with minimal effort.

---

## Conclusion

[`.gitattributes`](https://git-scm.com/docs/gitattributes) is not an advanced or optional feature—it is a foundational tool for maintaining repository correctness and consistency.

Teams that ignore it often compensate with conventions, editor settings, or CI workarounds.
Teams that use it intentionally prevent these problems at the source.

If your repository is shared across platforms, languages, or tooling ecosystems, [`.gitattributes`](https://git-scm.com/docs/gitattributes) deserves the same level of attention as `.gitignore`.
