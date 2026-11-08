import os
import sys
import json
import shutil
import subprocess
import site

# Try to find or import Pillow
Image = None
try:
    from PIL import Image
except ImportError:
    try:
        # On modern environments with PEP 668, pass --break-system-packages
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "Pillow", "--break-system-packages"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        # Add user site-packages to sys.path so the newly installed package is discoverable
        user_site = site.getusersitepackages()
        if user_site and user_site not in sys.path:
            sys.path.insert(0, user_site)
        if hasattr(site, "getsitepackages"):
            for sp in site.getsitepackages():
                if sp and sp not in sys.path:
                    sys.path.insert(0, sp)
        from PIL import Image
    except Exception as e:
        print(f"[NOTE] Pillow could not be imported: {e}. Will use system fallback.")
        Image = None

def generate_icons(logo_path):
    global Image

    if not os.path.exists(logo_path):
        print(f"[ERROR] Logo not found at {logo_path}")
        return

    print(f"Processing logo from {logo_path} (Pillow available: {Image is not None})...")

    # ========================================================
    # 1. ANDROID APP ICONS
    # ========================================================
    res_dir = os.path.join("android", "app", "src", "main", "res")
    os.makedirs(res_dir, exist_ok=True)

    # 1a. colors.xml with #0E0E0E dark background
    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml = os.path.join(values_dir, "colors.xml")
    with open(colors_xml, "w", encoding="utf-8") as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0E0E0E</color>
</resources>
''')
    print("Created colors.xml with background color #0E0E0E")

    # 1b. Adaptive icon XMLs in mipmap-anydpi-v26
    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    print("Created adaptive icon XMLs in mipmap-anydpi-v26")

    # 1c. Clean invalid files
    drawable_dir = os.path.join(res_dir, "drawable")
    os.makedirs(drawable_dir, exist_ok=True)
    for bad_f in ["ic_launcher.xml", "ic_launcher.png"]:
        p = os.path.join(drawable_dir, bad_f)
        if os.path.exists(p):
            try:
                os.remove(p)
            except Exception:
                pass

    # Copy logo to drawable/logo.png
    shutil.copyfile(logo_path, os.path.join(drawable_dir, "logo.png"))

    densities = [
        ("mipmap-mdpi", 48, 108),
        ("mipmap-hdpi", 72, 162),
        ("mipmap-xhdpi", 96, 216),
        ("mipmap-xxhdpi", 144, 324),
        ("mipmap-xxxhdpi", 192, 432),
    ]

    bg_color = (14, 14, 14, 255)

    if Image is not None:
        try:
            img = Image.open(logo_path).convert("RGBA")
            img_w, img_h = img.size

            for dir_name, legacy_sz, fg_sz in densities:
                target_dir = os.path.join(res_dir, dir_name)
                os.makedirs(target_dir, exist_ok=True)

                # Legacy raster icon (Black background with logo centered)
                legacy_canvas = Image.new("RGBA", (legacy_sz, legacy_sz), bg_color)
                target_inner = int(round(legacy_sz * 0.72))
                ratio = min(target_inner / img_w, target_inner / img_h)
                nw, nh = int(round(img_w * ratio)), int(round(img_h * ratio))
                scaled_logo = img.resize((nw, nh), Image.Resampling.LANCZOS)
                offset = ((legacy_sz - nw) // 2, (legacy_sz - nh) // 2)
                legacy_canvas.paste(scaled_logo, offset, scaled_logo)
                legacy_canvas.save(os.path.join(target_dir, "ic_launcher.png"), "PNG")
                legacy_canvas.save(os.path.join(target_dir, "ic_launcher_round.png"), "PNG")

                # Adaptive icon foreground (Transparent canvas with logo centered in 65% safe zone)
                fg_canvas = Image.new("RGBA", (fg_sz, fg_sz), (0, 0, 0, 0))
                target_fg_inner = int(round(fg_sz * 0.65))
                ratio_fg = min(target_fg_inner / img_w, target_fg_inner / img_h)
                nw_fg, nh_fg = int(round(img_w * ratio_fg)), int(round(img_h * ratio_fg))
                fg_scaled_logo = img.resize((nw_fg, nh_fg), Image.Resampling.LANCZOS)
                fg_offset = ((fg_sz - nw_fg) // 2, (fg_sz - nh_fg) // 2)
                fg_canvas.paste(fg_scaled_logo, fg_offset, fg_scaled_logo)
                fg_canvas.save(os.path.join(target_dir, "ic_launcher_foreground.png"), "PNG")

            print("[SUCCESS] Android icons generated with solid black background & adaptive foregrounds via PIL!")
        except Exception as e:
            print(f"[WARNING] PIL processing failed: {e}. Falling back to copy.")
            Image = None

    if Image is None:
        # Fallback without PIL:
        # Android adaptive icon will still paint #0E0E0E from colors.xml!
        for dir_name, _, _ in densities:
            target_dir = os.path.join(res_dir, dir_name)
            os.makedirs(target_dir, exist_ok=True)
            shutil.copyfile(logo_path, os.path.join(target_dir, "ic_launcher.png"))
            shutil.copyfile(logo_path, os.path.join(target_dir, "ic_launcher_round.png"))
            shutil.copyfile(logo_path, os.path.join(target_dir, "ic_launcher_foreground.png"))
        print("[SUCCESS] Android adaptive icons configured (background #0E0E0E applied via XML)!")

    # ========================================================
    # 2. IOS APP ICONS
    # ========================================================
    ios_icon_dir = os.path.join("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icon_dir):
        contents_path = os.path.join(ios_icon_dir, "Contents.json")
        if os.path.exists(contents_path):
            try:
                with open(contents_path, "r") as f:
                    data = json.load(f)
                for image_entry in data.get("images", []):
                    fn = image_entry.get("filename")
                    sz = image_entry.get("size", "")
                    sc = image_entry.get("scale", "1x")
                    if fn and sz:
                        w, h = [float(x) for x in sz.split("x")]
                        scale_val = float(sc.replace("x", ""))
                        px_w = int(round(w * scale_val))
                        px_h = int(round(h * scale_val))
                        out_p = os.path.join(ios_icon_dir, fn)

                        if Image is not None:
                            ios_canvas = Image.new("RGBA", (px_w, px_h), bg_color)
                            target_sz = int(round(min(px_w, px_h) * 0.72))
                            ratio = min(target_sz / img_w, target_sz / img_h)
                            nw, nh = int(round(img_w * ratio)), int(round(img_h * ratio))
                            scaled = img.resize((nw, nh), Image.Resampling.LANCZOS)
                            offset = ((px_w - nw) // 2, (px_h - nh) // 2)
                            ios_canvas.paste(scaled, offset, scaled)
                            ios_canvas.convert("RGB").save(out_p, "PNG")
                        else:
                            # Use macOS sips command if available
                            subprocess.run(["sips", "-z", str(px_h), str(px_w), logo_path, "--out", out_p], check=False)
                print("[SUCCESS] iOS app icons updated!")
            except Exception as e:
                print(f"[WARNING] iOS icon update encountered: {e}")

if __name__ == "__main__":
    try:
        candidates = ["png-01.png", "PNG-01.png", "assets/images/logo.png"]
        found = None
        for c in candidates:
            if os.path.exists(c):
                found = c
                break
        if found:
            generate_icons(found)
        else:
            print("[WARNING] No logo candidate found.")
    except Exception as e:
        print(f"[NOTE] Handled exception gracefully: {e}")
