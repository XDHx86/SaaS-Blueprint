"""Intra-repo markdown link resolution.

Every relative link target in a .md file must resolve to a real file or
directory in the repo (non-.md assets included: .mmd, .yml, .sh, Dockerfile,
Caddyfile, LICENSE, ...). Same-file anchor-only links (#frag) are handled by
_check_anchors.py.
"""
import os, re, glob

link_re = re.compile(r'(?!!)\[[^\]]*\]\(([^)]+)\)')

# Index every file in the repo, excluding version control / tooling caches.
import pathlib
root = pathlib.Path('.')
md_files = [str(p) for p in root.rglob('*.md')]

# Index every file/dir in the repo, including dotfiles. Use os.walk so hidden
# entries (.env.example, .github/, ...) are included — glob('**/*') skips them.
SKIP_DIRS = {'.git', '.claude', 'node_modules'}
all_files, all_dirs = [], []
for dirpath, dirnames, filenames in os.walk('.'):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    rel_dir = dirpath
    if rel_dir == '.':
        rel_dir = ''  # root — normalizes paths without leading ./
    for name in dirnames:
        p = os.path.join(dirpath, name)
        all_dirs.append(p)
    for name in filenames:
        p = os.path.join(dirpath, name)
        all_files.append(p)


def norm(p):
    return os.path.normpath(p).replace(os.sep, '/')


norm_files = {norm(f) for f in all_files}
norm_dirs = {norm(d) for d in all_dirs}

issues = []
for md in md_files:
    base = os.path.dirname(md)
    for m in link_re.finditer(open(md, encoding='utf-8').read()):
        target = m.group(1).strip()
        if target.startswith(('http://', 'https://', 'mailto:', 'data:')):
            continue
        if target[:1] == '<':
            continue
        path = target.split('#', 1)[0].strip()
        if path == '':
            continue  # same-file anchor
        cand = norm(os.path.join(base, path))
        if cand in norm_files or cand in norm_dirs:
            continue
        issues.append((md, target, cand))

if issues:
    print("UNRESOLVED LINKS: %d" % len(issues))
    for md, target, cand in issues:
        print("  %s: ](%s) -> %s" % (md, target, cand))
else:
    print("All intra-repo markdown links resolve.")
