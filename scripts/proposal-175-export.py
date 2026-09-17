"""Copy the named screenshot attachments out of an exported xcresult dump.

Usage: python3 scripts/proposal-175-export.py <exported-attachments-dir> <out-dir>
"""
import json
import os
import shutil
import sys

tmp, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
manifest = json.load(open(os.path.join(tmp, "manifest.json")))
for entry in manifest:
    for attachment in entry.get("attachments", []):
        name = attachment["suggestedHumanReadableName"]
        if not name or not name[0].isnumeric():
            continue
        clean = name.split("_")[0] + ".png"
        shutil.copy(os.path.join(tmp, attachment["exportedFileName"]),
                    os.path.join(out, clean))
        print("wrote " + clean)
