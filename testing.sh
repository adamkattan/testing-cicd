push_tag() {
  local tag_name="$1"

  if ! git tag "$tag_name"; then
    echo "Failed to create tag '$tag_name'" >&2
    exit 1
  fi

  if ! git push origin "$tag_name"; then
    echo "Failed to push tag '$tag_name'" >&2
    exit 1
  fi
}
delete_and_retag_major_version() {
  local major_version=$1

  git tag -d "$major_version" || {
    echo "Failed to delete tag $major_version"
    exit 1
  }
  git push origin --delete "$major_version" || {
    echo "Failed to push delete for tag $major_version"
    exit 1
  }

  push_tag "$major_version"
}

labels=$(echo `${{ toJson(github.event.pull_request.labels) }}`	| jq -r '.[]')

echo "Triggering actor - ${{ github.triggering_actor }}"
echo "Labels: $labels"

# this will get the latest_tag
latest_tag=$(git tag | sort -Vr | head -n 1)
echo "latest tag: $latest_tag"

latest_tag="${latest_tag#v}"
IFS='.' read -r major_slice minor_slice patch_slice <<< "$latest_tag"

# Set default values if any part is missing
major_slice=${major_slice:-0}
minor_slice=${minor_slice:-0}
patch_slice=${patch_slice:-0}
echo "slices: $major_slice.$minor_slice.$patch_slice"

echo "slices: $major_slice.$minor_slice.$patch_slice"

case $label in
patch)
    new_tag="v$major_slice.$minor_slice.$((patch_slice + 1))"
    push_tag $new_tag
    retag_major "v$major_slice"
    ;;
minor)
    new_tag="v$major_slice.$((minor_slice + 1)).0"
    push_tag $new_tag
    retag_major "v$major_slice"
    ;;
major)
    new_tag="v$((major_slice + 1)).0.0"
    push_tag $new_tag
    new_major_tag="v$((major_slice + 1))"
    push_tag $new_major_tag
    ;;
*)
    echo "Please specify label, choose only ONE from: major, minor, patch."
    ;;
esac
