#!/usr/bin/env python3
"""
Binary patch for libkickerplugin.so to add org.kombatant.fancytasks
to Kicker's hardcoded known task manager list.

This replaces the unused "org.kde.plasma.expandingiconstaskmanager" entry
with "org.kombatant.fancytasks" so that Kickoff/Kicker shows the
"Pin to Task Manager" option for FancyTasks.

Re-run after every plasma-workspace package update.

Usage:
    sudo python3 patch-kicker.py          # apply patch
    sudo python3 patch-kicker.py --revert # restore backup
"""

import argparse
import shutil
import struct
import sys
from pathlib import Path

LIB_PATH = Path("/usr/lib/qt6/qml/org/kde/plasma/private/kicker/libkickerplugin.so")
BACKUP_PATH = LIB_PATH.with_suffix(".so.bak")

OLD_STRING = b"org.kde.plasma.expandingiconstaskmanager"  # 40 bytes
NEW_STRING = b"org.kombatant.fancytasks"                 # 24 bytes

# x86-64 instruction: mov $imm32, %esi  →  be XX 00 00 00
MOV_ESI_OPCODE = 0xBE
# x86-64 instruction: lea disp32(%rip), %rdx  →  48 8d 15 XX XX XX XX
LEA_RDX_PREFIX = bytes([0x48, 0x8D, 0x15])


def find_length_instruction(data: bytearray, string_offset: int) -> int:
    """Find the 'mov $0x28,%esi' instruction that passes the string length
    to QString::fromLatin1, located just before the lea that loads the
    string pointer."""
    # Search backwards from the string for any lea that references it.
    # The lea is: 48 8d 15 <disp32>  (7 bytes)
    # disp32 is relative to the instruction *after* the lea (rip-relative).
    # Before the lea, there should be: be <len32> (5 bytes) — mov $len,%esi
    for candidate in range(0x1000, len(data) - 16):
        if data[candidate:candidate + 3] != LEA_RDX_PREFIX:
            continue
        disp = struct.unpack_from("<i", data, candidate + 3)[0]
        target = candidate + 7 + disp  # rip points past the 7-byte lea
        if target == string_offset:
            # Found the lea. The mov $len,%esi should be the 5 bytes before it.
            mov_offset = candidate - 5
            if data[mov_offset] == MOV_ESI_OPCODE:
                embedded_len = struct.unpack_from("<I", data, mov_offset + 1)[0]
                return mov_offset
    return -1


def apply_patch():
    if not LIB_PATH.exists():
        sys.exit(f"Error: {LIB_PATH} not found.")

    data = bytearray(LIB_PATH.read_bytes())

    # --- Check if already patched ---
    if data.find(NEW_STRING) != -1 and data.find(OLD_STRING) == -1:
        print("Already patched. Nothing to do.")
        return

    # --- Locate the old string ---
    str_offset = data.find(OLD_STRING)
    if str_offset == -1:
        sys.exit("Error: Could not find the target string in the library.\n"
                 "The library version may be incompatible.")

    if data.count(OLD_STRING) != 1:
        sys.exit("Error: Multiple occurrences of the target string found. Aborting.")

    # --- Locate the length instruction ---
    mov_offset = find_length_instruction(data, str_offset)
    if mov_offset == -1:
        sys.exit("Error: Could not find the string-length instruction.\n"
                 "The library version may be incompatible.")

    old_len = struct.unpack_from("<I", data, mov_offset + 1)[0]
    if old_len != len(OLD_STRING):
        sys.exit(f"Error: Expected embedded length {len(OLD_STRING)}, "
                 f"found {old_len}. Aborting.")

    # --- Create backup ---
    if not BACKUP_PATH.exists():
        shutil.copy2(LIB_PATH, BACKUP_PATH)
        print(f"Backup saved to {BACKUP_PATH}")
    else:
        print(f"Backup already exists at {BACKUP_PATH}")

    # --- Patch the string (pad with null bytes to keep same size) ---
    padded = NEW_STRING + b"\x00" * (len(OLD_STRING) - len(NEW_STRING))
    data[str_offset:str_offset + len(OLD_STRING)] = padded

    # --- Patch the length ---
    struct.pack_into("<I", data, mov_offset + 1, len(NEW_STRING))

    LIB_PATH.write_bytes(data)

    print(f"Patched {LIB_PATH}:")
    print(f"  String: {OLD_STRING.decode()!r} -> {NEW_STRING.decode()!r}")
    print(f"  Length: {len(OLD_STRING)} -> {len(NEW_STRING)}")
    print()
    print("Restart plasmashell to apply:")
    print("  kquitapp6 plasmashell && plasmashell --replace &")


def revert_patch():
    if not BACKUP_PATH.exists():
        sys.exit(f"Error: No backup found at {BACKUP_PATH}")
    shutil.copy2(BACKUP_PATH, LIB_PATH)
    BACKUP_PATH.unlink()
    print(f"Restored {LIB_PATH} from backup.")
    print()
    print("Restart plasmashell to apply:")
    print("  kquitapp6 plasmashell && plasmashell --replace &")


def main():
    parser = argparse.ArgumentParser(
        description="Patch libkickerplugin.so to recognize FancyTasks")
    parser.add_argument("--revert", action="store_true",
                        help="Restore the original unpatched library")
    args = parser.parse_args()

    if args.revert:
        revert_patch()
    else:
        apply_patch()


if __name__ == "__main__":
    main()
