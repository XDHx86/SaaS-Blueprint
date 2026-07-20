import os, re, glob

link_re = re.compile(r'(?!!)\[([^\]]*)\]\(([^)]+)\)')
files = glob.glob('**/*.md', recursive=True)
texts = {}
for f in files:
    with open(f, encoding='utf-8') as fh:
        texts[f] = fh.read()


def slug(text):
    s = re.sub(r'[`*_{}#\[\]<>!]', '', text)
    s = s.strip().lower().replace(' ', '-')
    s = re.sub(r'[^\w-]', '', s)
    return s


def file_slugs(t):
    out = set()
    for m in re.finditer(r'(?m)^\s{0,3}(\#{1,6})\s+(.+?)\s*$', t):
        out.add(slug(m.group(2)))
    return out


def norm(p):
    return os.path.normpath(p).replace('\\', '/')


issues = []
norm_to_file = {norm(f): f for f in files}

for md in files:
    base = os.path.dirname(md)
    for m in link_re.finditer(texts[md]):
        target = m.group(2).strip()
        if target.startswith(('http://', 'https://', 'mailto:', 'data:')):
            continue
        if target[:1] == '<':
            continue
        if '#' not in target:
            continue
        path, frag = target.split('#', 1)
        if path == '':
            if frag and frag not in file_slugs(texts[md]):
                issues.append((md, target, '(this file)', 'no heading #' + frag))
            continue
        cand = norm(os.path.join(base, path))
        if cand not in norm_to_file:
            continue  # file existence handled elsewhere
        tgt_text = texts[norm_to_file[cand]]
        if frag not in file_slugs(tgt_text):
            issues.append((md, target, cand, 'no heading #' + frag))

if issues:
    print("ANCHOR ISSUES: %d" % len(issues))
    for md, target, cand, why in issues:
        print("  %s: ](%s) -> %s: %s" % (md, target, cand, why))
else:
    print("All cross-file anchors resolve to a heading.")
