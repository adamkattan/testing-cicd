#!/bin/bash
push_tag() {
    local tag_to_push=$1
    git tag "$tag_to_push" || { echo "Failed to create tag $tag_to_push"; exit 1; }
    git push origin "$tag_to_push" || { echo "Failed to push tag $tag_to_push"; exit 1; }
    echo "tag: $tag_to_push was pushed successfully."
}
retag_major() {
    local pushed_tag_major_version=$1

    git tag -d "$pushed_tag_major_version" || { echo "Failed to delete tag $pushed_tag_major_version"; exit 1; }
    git push origin --delete "$pushed_tag_major_version" || { echo "Failed to push delete for tag $pushed_tag_major_version"; exit 1; }
    echo "tag: $pushed_tag_major_version was deleted successfully." 

    push_tag $pushed_tag_major_version
}

echo "Triggering actor - ${{ github.triggering_actor }}"

prefix_label=""
semver_label=""
for label in $(echo '${{ toJson(github.event.pull_request.labels) }}' | jq -r 'map(.name) | join(" ")'); do

    case "$label" in
        no-tag)
            exit 0;
        ;;
        wf-generic-build-deploy)
            prefix_label="$label-"
        ;;
        major|minor|patch)
            semver_label=$label
        ;;
    esac

done

# This will get the latest_tag for the corresponding label
latest_tag=$(git tag -l "${prefix_label}v*" | sort -Vr | head -n 1)
echo "latest tag: $latest_tag"

latest_tag="${latest_tag#$prefix_label}"
latest_tag="${latest_tag#v}"
IFS='.' read -r major_slice minor_slice patch_slice <<< "$latest_tag"

# Set default values if any part is missing
major_slice=${major_slice:-0}
minor_slice=${minor_slice:-0}
patch_slice=${patch_slice:-0}
echo "slices: $major_slice.$minor_slice.$patch_slice"

echo "slices: $major_slice.$minor_slice.$patch_slice"

tag_prefix="v"

case $semver_label in
    patch)
        new_tag="$prefix_label$tag_prefix$major_slice.$minor_slice.$((patch_slice + 1))"
        push_tag $new_tag
        retag_major "$prefix_label$tag_prefix$major_slice"
        ;;
    minor)
        new_tag="$prefix_label$tag_prefix$major_slice.$((minor_slice + 1)).0"
        push_tag $new_tag
        retag_major "$prefix_label$tag_prefix$major_slice"
        ;;
    major)
        new_tag="$prefix_label$tag_prefix$((major_slice + 1)).0.0"
        push_tag $new_tag
        new_major_tag="$prefix_label$tag_prefix$((major_slice + 1))"
        push_tag $new_major_tag
        ;;
    *)
        echo "Please specify label, choose only ONE from: major, minor, patch."
        ;;
esac
