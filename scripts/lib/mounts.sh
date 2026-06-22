#!/bin/bash
# Helpers to configure permanent, fstab-based mount points for the media
# disks (Films / Series / Music), independent from desktop auto-mount
# (udisks/GVFS), which is what causes the "Films1" duplicate-mount issue
# when a previous session left a stale mount point behind.

# mountpoint_configured <path>
# Returns 0 if /etc/fstab already has an entry for this mountpoint AND it is
# currently mounted there.
mountpoint_configured() {
    local path="$1"
    grep -qE "[[:space:]]${path}[[:space:]]" /etc/fstab 2>/dev/null && mountpoint -q "$path"
}

# list_candidate_partitions
# Prints "NAME SIZE FSTYPE LABEL" for partitions not already mounted under
# /srv/media, one per line, for use with gum choose.
list_candidate_partitions() {
    lsblk -rno NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT |
        awk '$3 != "" && $5 !~ /^\/srv\/media\// { printf "%-10s %-8s %-8s %s\n", $1, $2, $3, $4 }'
}

# configure_mount <name> <device> <target>
# name:   "Films" | "Series" | "Music" (used only for messages)
# device: e.g. "sdb1" (lsblk NAME, without /dev/ prefix)
# target: e.g. "/srv/media/Films"
#
# Idempotent: skips appending to /etc/fstab if an entry for this UUID or
# mountpoint already exists.
configure_mount() {
    local name="$1" device="$2" target="$3"
    local devpath="/dev/${device}"

    local uuid fstype
    uuid="$(sudo blkid -s UUID -o value "$devpath")"
    fstype="$(sudo blkid -s TYPE -o value "$devpath")"

    if [ -z "$uuid" ]; then
        echo "Could not read the UUID of ${devpath}" >&2
        return 1
    fi

    sudo mkdir -p "$target"

    local opts="defaults,nofail,x-systemd.automount"
    case "$fstype" in
        vfat|exfat|ntfs|ntfs3)
            opts="${opts},uid=1000,gid=1000"
            ;;
    esac

    if ! grep -q "UUID=${uuid}" /etc/fstab && ! grep -qE "[[:space:]]${target}[[:space:]]" /etc/fstab; then
        echo "UUID=${uuid} ${target} ${fstype} ${opts} 0 2" | sudo tee -a /etc/fstab > /dev/null
    fi

    sudo systemctl daemon-reload 2>/dev/null

    # Some filesystem drivers (ntfs3) refuse to mount the same block device a
    # second time. If the desktop auto-mounted it elsewhere, free it first.
    local current_mountpoint
    current_mountpoint="$(findmnt -n -o TARGET "$devpath" 2>/dev/null)"
    if [ -n "$current_mountpoint" ] && [ "$current_mountpoint" != "$target" ]; then
        sudo umount "$devpath" 2>/dev/null
    fi

    if ! mountpoint -q "$target"; then
        sudo mount "$target"
    fi

    case "$fstype" in
        ext4|btrfs|xfs)
            sudo chown -R "$(id -u)":"$(id -g)" "$target" 2>/dev/null
            ;;
    esac

    mountpoint -q "$target"
}

# offer_migration <old_path> <new_path>
# If data exists at the old desktop-automount location, offers (never forces)
# an rsync copy to the new permanent mount point. Never deletes the old data.
offer_migration() {
    local old_path="$1" new_path="$2"

    if [ -d "$old_path" ] && [ -n "$(ls -A "$old_path" 2>/dev/null)" ]; then
        if command -v gum &> /dev/null; then
            if gum confirm "Data exists in ${old_path}. Copy it to ${new_path}?" --default=false; then
                rsync -a --info=progress2 "${old_path}/" "${new_path}/"
                echo "Copy complete. Check the content, then manually delete ${old_path} once verified."
            fi
        fi
    fi
}
