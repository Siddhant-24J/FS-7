import os
import sys

# Forward to generate_app_icons.py
script_dir = os.path.dirname(os.path.abspath(__file__))
app_icons_path = os.path.join(script_dir, "generate_app_icons.py")

if __name__ == "__main__":
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("generate_app_icons", app_icons_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        candidates = ["png-01.png", "PNG-01.png", "assets/images/logo.png"]
        found = None
        for c in candidates:
            if os.path.exists(c):
                found = c
                break
        if found:
            module.generate_icons(found)
    except Exception as e:
        print(f"[NOTE] generate_android_icons handled: {e}")
