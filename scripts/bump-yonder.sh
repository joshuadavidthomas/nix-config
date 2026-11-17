#!/usr/bin/env bash
# scripts/bump-yonder.sh TAG: pin the lab boxes to yonder's release TAG, as one commit on a new
# branch yonder-TAG (docs/changes.md#update-inputs; yonder's wiki/plans/release-template.md,
# step 6). Run from the repo's root, on the Mac or in an orb, with a `gh` login that can read
# joshuadavidthomas/yonder.dev (private). Checks, before it commits: TAG has a published GitHub
# release; the lock pins TAG's commit under TAG's name; the package lab-3 will build says it is
# TAG; `nix flake check` passes. Prints the branch it made. It pushes nothing: pushing the
# branch, the pull request, the dry-activate on each box and the merge are by hand.
set -euo pipefail
tag=$1
repo=joshuadavidthomas/yonder.dev
[[ $tag =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc(0|[1-9][0-9]*))?$ ]] || {
	echo "$tag is not a release's name (vX.Y.Z or vX.Y.Z-rcN)" >&2
	exit 1
}
token=$(gh auth token)
export NIX_CONFIG="access-tokens = github.com=$token"
yonder() { GH_TOKEN=$token gh "$@"; }

# A tag is pinned only once release.yml has published its release (its gates passed).
release=$(yonder release view "$tag" -R "$repo" --json isDraft,url --jq 'select(.isDraft | not) | .url')
[[ -n $release ]] || {
	echo "$tag has no published release" >&2
	exit 1
}
# The tag's commit: an annotated tag's object, or a commit for a lightweight one.
ref=$(yonder api "repos/$repo/git/ref/tags/$tag" --jq '.object.type + " " + .object.sha')
commit=${ref#* }
[[ $ref == "tag "* ]] && commit=$(yonder api "repos/$repo/git/tags/$commit" --jq .object.sha)
subject=$(yonder api "repos/$repo/git/tags/${ref#* }" --jq '.message | split("\n")[0]' 2>/dev/null || true)
subject=${subject#"$tag: "}

old=$(sed -nE 's|^ *yonder\.url = "github:joshuadavidthomas/yonder\.dev/([^"]+)";$|\1|p' flake.nix)
[[ $(wc -l <<<"$old") -eq 1 && -n $old ]] || {
	echo "flake.nix has no single yonder.url line" >&2
	exit 1
}
[[ $old != "$tag" ]] || {
	echo "flake.nix already pins $tag" >&2
	exit 1
}
sed -i -E "s|^( *yonder\.url = \"github:joshuadavidthomas/yonder\.dev/)[^\"]+(\";)$|\1$tag\2|" flake.nix
nix flake update yonder

lock=$(jq -c '.nodes.yonder | {ref: .original.ref, rev: .locked.rev}' flake.lock)
echo "flake.lock: $lock"
[[ $lock == "{\"ref\":\"$tag\",\"rev\":\"$commit\"}" ]] || {
	echo "the lock should pin $tag at $commit" >&2
	exit 1
}

# The package a box builds, named from the lock by the overlay, says it is the tag at its
# commit, for its CLI and its yonderd (run here with the in-memory VMM), and `yonder version`
# exits 0, as yonder's tests/release/release-name.sh checks before the tag.
pkg=$(nix build --no-link --print-out-paths .#nixosConfigurations.lab-3.config.services.yonder.package)
dir=$(mktemp -d)
"$pkg/bin/yonderd" --vmm fake --state-dir "$dir/state" --run-dir "$dir/run" --resolver-listen 127.0.0.1:5398 >"$dir/yonderd.log" 2>&1 &
yonderd=$!
for _ in $(seq 60); do
	[[ -S $dir/run/yonderd.sock ]] && break
	sleep 1
done
version=$("$pkg/bin/yonder" --socket "$dir/run/yonderd.sock" version) || version="$version (exit $?)"
kill "$yonderd"
printf 'yonder version: %s\n' "$version" | sed '2,$s/^/yonder version: /'
[[ $(grep -cF "$tag  ${commit:0:12}" <<<"$version") -eq 2 && $version != *"(exit "* ]] || {
	echo "the package lab-3 builds does not say it is $tag at $commit, clean" >&2
	exit 1
}

nix flake check

# docs/yonder.md moves with the pin (AGENTS.md): a paragraph after the last pin's. What the
# release changes, and the order its deploy takes, are on its release page.
today=$(date -u +%F)
para=$(fold -s -w 95 <<<"The pin moved to \`$tag\` on $today${subject:+: $subject}. What it changes, and the order its deploy takes, are in its release notes: <$release>." | sed 's/ *$//')
PARA=$para awk '
	{ lines[NR] = $0 }
	/^The pin moved to `/ { last = NR }
	END {
		if (!last) { print "docs/yonder.md has no pin paragraph" > "/dev/stderr"; exit 1 }
		end = last
		while (end < NR && lines[end + 1] != "") end++
		for (i = 1; i <= NR; i++) {
			print lines[i]
			if (i == end) { print ""; print ENVIRON["PARA"] }
		}
	}' docs/yonder.md >docs/yonder.md.new
mv docs/yonder.md.new docs/yonder.md

branch=yonder-$tag
git switch -q -c "$branch"
git add flake.nix flake.lock docs/yonder.md
git commit -q -m "yonder: pin $tag" -m "$subject" -m "Release notes: $release"
echo "$branch"
