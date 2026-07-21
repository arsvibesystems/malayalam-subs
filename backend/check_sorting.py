"""Check sorting order of the 3 items the user mentioned."""
import subprocess, json, sys
sys.stdout.reconfigure(encoding='utf-8')

result = subprocess.run(
    ["git", "show", "HEAD:data/subtitles.json"],
    capture_output=True, text=True, encoding="utf-8"
)
data = json.loads(result.stdout)

# Find the 3 items
targets = ["citizen-vigilante-2026", "alice-creed", "wishes-could-kill"]
found = []
for d in data:
    slug = d.get("slug", "")
    source_url = d.get("source_url", "").lower()
    for t in targets:
        if t in slug or t in source_url:
            found.append(d)
            break

print(f"Found {len(found)} matching items:\n")
for d in found:
    idx = data.index(d)
    print(f"Position in array: {idx}")
    print(f"  slug: {d.get('slug')}")
    print(f"  source_site: {d.get('source_site')}")
    print(f"  release_number: {d.get('release_number')}")
    print(f"  updated_at: {d.get('updated_at')}")
    print(f"  created_at: {d.get('created_at')}")
    print()

# Also show the first 15 items in the array (what the app sees as "latest")
print("=== First 15 items in array (app shows these as 'latest') ===\n")
for i, d in enumerate(data[:15]):
    print(f"#{i+1} [{d.get('source_site')}] {d.get('slug')}")
    print(f"     updated_at: {d.get('updated_at')}")
    print(f"     release_number: {d.get('release_number')}")
    print()
