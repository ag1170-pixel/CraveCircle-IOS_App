import os
import sys
import shutil
import json

def add_asset(image_path, asset_name):
    base_dir = "/Users/user38/Projects/CraveCircle.cc/AICookBook/Assets.xcassets"
    asset_dir = os.path.join(base_dir, f"{asset_name}.imageset")
    os.makedirs(asset_dir, exist_ok=True)
    
    # Check image extension
    ext = os.path.splitext(image_path)[1].lower()
    if not ext: ext = ".png"
    
    dest_path = os.path.join(asset_dir, f"{asset_name}{ext}")
    shutil.copy(image_path, dest_path)
    
    contents = {
      "images": [
        {
          "idiom": "universal",
          "filename": f"{asset_name}{ext}",
          "scale": "1x"
        },
        {
          "idiom": "universal",
          "scale": "2x"
        },
        {
          "idiom": "universal",
          "scale": "3x"
        }
      ],
      "info": {
        "author": "xcode",
        "version": 1
      }
    }
    
    with open(os.path.join(asset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print(f"Successfully added {asset_name} to Assets.xcassets")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 add_asset.py <image_path> <asset_name>")
        sys.exit(1)
    add_asset(sys.argv[1], sys.argv[2])
